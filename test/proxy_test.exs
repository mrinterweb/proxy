require IEx
defmodule ProxyTest do
  use ExUnit.Case, async: false

  describe "update_html/1" do
    test "replaces html" do
      input    = ~s(<html><body><a href="http://www.bbc.com/foo">Blah</a></body></html>)
      expected = ~s(<html><body><a href="http://localhost:4001/foo">Blah</a></body></html>)
      assert Proxy.update_html(input) == expected
    end

    @tag focus: true, timeout: 600000
    test "converts bbc.com" do
      page = File.read!("test/pages/bbc.com.html")

      updated = Proxy.update_html(page)
      hrefs = updated
        |> Floki.find("a")
        |> Floki.attribute("href")
        |> Enum.uniq

      domain = "bbc.com"
      {:ok, domain_reg} = Regex.compile("^https?://[a-z0-9\-\.]*#{Regex.escape(domain)}")

      assert hrefs |> Enum.all?(fn(url) ->
        IO.puts "testing url: #{url}"
        assert !String.match?(url, domain_reg)
      end)
    end
  end
end
