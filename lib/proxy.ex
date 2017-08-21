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
      {:ok, response} -> response
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
    parsed = update_html(response.body)
    send_resp(conn, response.status_code, parsed)
  end

  defp uri(conn) do
    base = @target <> Enum.join(conn.path_info, "/")
    case conn.query_string do
      "" -> base
      qs -> base <> "?" <> qs
    end
    base
  end

  def update_html(html) do
    parsed = html |> Floki.parse

    hrefs = parsed
      |> Floki.find("a")
      |> Floki.attribute("href")

    # Itterate over domains to replace
    ["bbc.com"]
      |> Enum.reduce(html, fn(domain, accum1) ->
        {:ok, domain_reg} = Regex.compile("^https?://[a-z0-9\-\.]*#{Regex.escape(domain)}")

        hrefs
          |> Enum.map(fn(url) ->
            if String.match?(url, domain_reg) do
              %{host: host, scheme: scheme} = URI.parse(url)
              "#{scheme}://#{host}"
            else
              nil
            end
          end)
          |> Enum.reject(&is_nil/1)
          |> Enum.uniq
          |> Enum.reduce(accum1, fn(base_url, accum2) ->
            IO.puts "replacing: #{base_url}"
            accum2 |> String.replace(base_url, "http://localhost:4001")
          end)
      end)
  end
end
