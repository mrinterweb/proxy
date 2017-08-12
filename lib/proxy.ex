require IEx

defmodule Proxy do
  use Plug.Builder
  import Plug.Conn

  @target "http://bbc.com/"

  plug Plug.Logger
  plug :dispatch

  def start(_argv) do
    port = 4001
    IO.puts "Running Proxy with Cowboy on http://localhost:#{port}"
    Plug.Adapters.Cowboy.http __MODULE__, [], port: port
    HTTPoison.start()
    :timer.sleep(:infinity)
  end

  def dispatch(conn, _opts) do
    # Start a request to the client saying we will stream the body.
    # We are simply passing all req_headers forward.
    url = uri(conn)
    response = case HTTPoison.get(url, [], [{:follow_redirect, true}]) do
      {:ok, response} ->
        response
      {:error, %HTTPoison.Error{reason: reason}} ->
        IO.inspect reason
        %{headers: nil, status: 404, body: "<html><body><h1>Not found</h1></body></html>"}
    end

    headers = response.headers
    if (headers) do
      headers = headers
                |> List.keydelete("Transfer-Encoding", 0)
                |> List.keydelete("Location", 0)
                |> List.insert_at(0, {"Location", "http://localhost:4001"})
      %{conn | resp_headers: headers}
    end
    send_resp(conn, response.status_code, response.body)
  end

  defp uri(conn) do
    base = @target <> Enum.join(conn.path_info, "/")
    case conn.query_string do
      "" -> base
      qs -> base <> "?" <> qs
    end
    base
  end
end
