defmodule EthereumJSONRPC.HTTP.HTTPoison do
  @moduledoc """
  Uses `HTTPoison` for `EthereumJSONRPC.HTTP`
  """
  require Logger

  alias EthereumJSONRPC.HTTP

  @behaviour HTTP

  def contains_zevm_request(json) do
    String.contains? Kernel.inspect(json) , "zevm"
  end

  @impl HTTP
  def json_rpc(url, json, options) when is_binary(url) and is_list(options) do
    if !contains_zevm_request(json) do
      case HTTPoison.post(url, json, [{"Content-Type", "application/json"}], options) do
        {:ok, %HTTPoison.Response{body: body, status_code: status_code}} ->
          {:ok, %{body: body, status_code: status_code}}

        {:error, %HTTPoison.Error{reason: reason}} ->
          {:error, reason}
      end
    else
      # Custom rpc endpoints does not allow batch requests
      {:ok, list} = Jason.decode(json)

      # todo (@Martin): fix this part.

      responses = Enum.map(list,
                        fn request -> (
                          if (request[:method] != nil && String.contains? request[:method] , "zevm") do
                            [path_param | _tail] = (if  is_map(request) && Map.has_key?(request, :params), do: request[:params], else: [])
                            zevm_path = "zeta-chain/zevm/" <> request[:method] <> (if path_param != nil, do:  "/" <> path_param, else: "")
                            zevm_url = (if (String.contains? request[:method] , "zevm"), do: String.replace(url, "evm", zevm_path), else: url)

                            HTTPoison.get(zevm_url, [], options)
                          else
                            HTTPoison.post(url, Jason.encode_to_iodata!(request), [{"Content-Type", "application/json"}], options)
                          end
                        ) end)

      successes = responses
                    |> Enum.filter(fn res -> case res do
                      {:ok, _other} ->
                        true

                      {:error, _other} ->
                        false
                    end end)
                    |> Enum.map(fn res ->
                      {:ok, %HTTPoison.Response{body: body}} = res
                      body end)

      errors = responses
                |> Enum.filter(fn res -> case res do
                  {:ok, _other} ->
                    false

                  {:error, _other} ->
                    true
                end  end)
                |> Enum.map(fn res ->
                  {:error, %HTTPoison.Error{reason: reason}} = res
                    reason end)

      Logger.info "responses " <> inspect(responses)
      Logger.info "successes " <> inspect(successes)
      Logger.info "errors " <> inspect(errors)

      if length(errors) > 0 do
        {:error, errors}
      else
        {:ok, %{body: responses, status_code: 200}}
      end
    end
  end

  def json_rpc(url, _json, _options) when is_nil(url), do: {:error, "URL is nil"}
end
