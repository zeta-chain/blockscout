defmodule EthereumJSONRPC.Block.ZEvmByTag do
  @moduledoc """
  Block format returned by [`zevm_getBlockByNumber`]
  when used with a semantic tag name instead of a number.
  """

  import EthereumJSONRPC, only: [quantity_to_integer: 1]

  def request(%{id: id, tag: tag}) when is_binary(tag) do
    EthereumJSONRPC.request(%{id: id, method: "zevm_getBlockByNumber", params: [tag, false]})
  end

  def number_from_result({:ok, %{"number" => nil}}), do: {:error, :not_found}

  def number_from_result({:ok, %{"number" => quantity}}) when is_binary(quantity) do
    {:ok, quantity_to_integer(quantity)}
  end

  def number_from_result({:ok, nil}), do: {:error, :not_found}

  def number_from_result({:error, %{"code" => -32602}}), do: {:error, :invalid_tag}
  def number_from_result({:error, _} = error), do: error
end
