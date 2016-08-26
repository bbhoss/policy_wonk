defmodule PolicyWonk.Utils do
  @moduledoc false
  

  #----------------------------------------------------------------------------
  def call_policy( handlers, conn, policy ) do
    call_into_list(handlers, fn(handler) ->
      handler.policy(conn, policy)
    end)
    |> case do
      :not_found ->
        # policy wasn't found on any handler. raise an error
        msg = "#{IO.ANSI.red}Unable find to a #{IO.ANSI.yellow}policy#{IO.ANSI.red} definition for:\n" <>
          "#{IO.ANSI.green}Policy: #{IO.ANSI.yellow}#{inspect(policy)}\n" <>
          "#{IO.ANSI.green}In any of the following modules...#{IO.ANSI.yellow}\n" <>
          build_handlers_msg( handlers ) <>
          IO.ANSI.red
        raise %PolicyWonk.Enforce.Error{ message: msg }
      :ok ->                                {:ok, conn}
      true ->                               {:ok, conn}
      false ->                              {:err, conn, nil}
      {:ok, policy_conn = %Plug.Conn{}} ->  {:ok, policy_conn}
      {:err, err_data} ->                   {:err, conn, err_data}
      _ ->                                  raise "malformed policy response"
    end
  end

  #----------------------------------------------------------------------------
  def call_policy_error( handlers, conn, err_data ) do
    call_into_list(handlers, fn(handler) ->
      handler.policy_error(conn, err_data )
    end)
    |> case do
      :not_found ->
        # policy_error wasn't found on any handler. raise an error
        msg = "#{IO.ANSI.red}Unable find to a #{IO.ANSI.yellow}policy_error#{IO.ANSI.red} definition for...\n" <>
          "#{IO.ANSI.green}err_data: #{IO.ANSI.red}#{inspect(err_data)}\n" <>
          "#{IO.ANSI.green}In any of the following modules...#{IO.ANSI.yellow}\n" <>
          build_handlers_msg( handlers ) <>
          IO.ANSI.red
        raise %PolicyWonk.Enforce.Error{ message: msg }
      conn = %Plug.Conn{} ->  conn
      _ -> raise              "policy_error must return a conn"
    end
  end

  #----------------------------------------------------------------------------
  def call_loader( handlers, conn, resource ) do
    call_into_list(handlers, fn(handler) ->
      handler.load_resource( conn, resource, conn.params )
    end)
    |> case do
      :not_found ->
        # load_resource wasn't found on any handler. raise an error
        msg = "#{IO.ANSI.red}Unable find to a #{IO.ANSI.yellow}load_resource#{IO.ANSI.red} definition for:\n" <>
          "#{IO.ANSI.green}Loader: #{IO.ANSI.yellow}#{inspect(resource)}\n" <>
          "#{IO.ANSI.green}Params: #{IO.ANSI.yellow}#{inspect(conn.params)}\n" <>
          "#{IO.ANSI.green}In any of the following modules...#{IO.ANSI.yellow}\n" <>
          build_handlers_msg( handlers ) <>
          IO.ANSI.red
        raise %PolicyWonk.LoadResource.Error{ message: msg }
      response -> response
    end
  end 
  #----------------------------------------------------------------------------
  def call_loader_error( handlers, conn, err_data ) do
    call_into_list(handlers, fn(handler) ->
      handler.load_error(conn, err_data )
    end)
    |> case do
      :not_found ->
        # loader_error wasn't found on any handler. raise an error
        msg = "#{IO.ANSI.red}Unable find to a #{IO.ANSI.yellow}load_error#{IO.ANSI.red} definition for...\n" <>
          "#{IO.ANSI.green}err_data: #{IO.ANSI.red}#{inspect(err_data)}\n" <>
          "#{IO.ANSI.green}In any of the following modules...#{IO.ANSI.yellow}\n" <>
          build_handlers_msg( handlers ) <>
          IO.ANSI.red
        raise %PolicyWonk.LoadResource.Error{ message: msg }
      conn = %Plug.Conn{} ->  {:halt, conn}
      _ ->                    raise "load_error must return a conn"
    end
  end

  #----------------------------------------------------------------------------
  def append_truthy(list, element) when is_list(list) do
    cond do
      is_list(element) -> list ++ element
      element ->          list ++ [element]
      true ->             list
    end
  end

  #----------------------------------------------------------------------------
  defp call_into_list( handlers, callback ) do
    Enum.find_value(handlers, :not_found, fn(handler) ->
      case handler do
        nil -> false  # empty spot in the handler list
        h ->
          try do
            callback.( h )
          rescue
            _e in UndefinedFunctionError ->
              # try the next handler in the list
              false
            _e in FunctionClauseError -> false
            e ->
              # some other error. let it raise
              raise e
          end
      end
    end)
  end

  #----------------------------------------------------------------------------
  defp build_handlers_msg( handlers ) do
    Enum.reduce(handlers, "", fn(h, acc) ->
      case h do
        nil -> acc
        mod -> acc <> inspect(mod) <> "\n"
      end
    end)
  end

end
