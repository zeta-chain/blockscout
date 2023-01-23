defmodule EthereumJSONRPC.HTTP.HTTPoison do
  @moduledoc """
  Uses `HTTPoison` for `EthereumJSONRPC.HTTP`
  """

  alias EthereumJSONRPC.HTTP

  @behaviour HTTP

  defp contains_zevm_request(json) do
    String.contains? Kernel.inspect(json) , "zevm"
  end


  defp is_error(res) do
    case res do
      {:ok, %HTTPoison.Response{body: body}} ->
        String.contains? Kernel.inspect(body) , "error" # Response's body can contain an error such as method not found.

        {:error, _error} ->
          true
    end

  end

  defp get_error(res) do
    case res do
      {:ok, %HTTPoison.Response{body: body}} ->
        case String.contains? Kernel.inspect(body) , "error" do # Response's body can contain an error such as method not found.
          true ->
            {:ok, decoded} = Jason.decode(body)
            decoded["error"]["message"]
          false ->
            nil
        end

        {:error, %HTTPoison.Error{reason: reason}} ->
          reason
    end
  end

  defp format_success_body_as_jsonrpc(res) do
    {:ok, %HTTPoison.Response{body: body}} = res
    "{\"jsonrpc\":\"2.0\", \"id\": 0, \"result\": #{body}}"
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
      # Custom zevm endpoints does not allow batch requests
      {:ok, list} = Jason.decode(json)

      responses = Enum.map(list,
                        fn request -> (
                          if (request["method"] != nil && String.contains? request["method"] , "zevm") do
                            [path_param | _tail] = (if  is_map(request) && Map.has_key?(request, "params"), do: request["params"], else: [])
                            zevm_path = "zeta-chain/zevm/" <> request["method"] <> (if path_param != nil, do:  "/" <> path_param, else: "")
                            zevm_url = (if (String.contains? request["method"] , "zevm"), do: String.replace(url, "evm", zevm_path), else: url)

                            HTTPoison.get(zevm_url, [], options)
                          else
                            HTTPoison.post(url, Jason.encode_to_iodata!(request), [{"Content-Type", "application/json"}], options)
                          end
                        ) end)

      successes = responses
                    |> Enum.filter(fn res -> !is_error(res) end)
                    |> Enum.map(fn res -> format_success_body_as_jsonrpc(res) end)

      errors = responses
                |> Enum.filter(fn res -> is_error(res) end)
                |> Enum.map(fn res -> get_error(res) end)

      if length(errors) > 0 do
        {:error, errors}
      else
        {:ok, %{body: "[#{Enum.join(successes, ",")}]", status_code: 200}}
      end
    end
  end

  def json_rpc(url, _json, _options) when is_nil(url), do: {:error, "URL is nil"}
end
