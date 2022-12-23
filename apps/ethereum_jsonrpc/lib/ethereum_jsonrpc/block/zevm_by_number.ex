defmodule EthereumJSONRPC.Block.ZEvmByNumber do
  @moduledoc """
  Block format as returned by [`zevm_getBlockByNumber`]
  """

  import EthereumJSONRPC, only: [integer_to_quantity: 1]

  def request(%{id: id, number: number}) do
    EthereumJSONRPC.request(%{id: id, method: "zevm_getBlockByNumber", params: [integer_to_quantity(number), true]})
  end
end
