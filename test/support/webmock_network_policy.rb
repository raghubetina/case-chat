module WebMockNetworkPolicy
  SELENIUM_PORT = 4444

  def self.apply!(environment = ENV)
    options = {allow_localhost: true}
    selenium_host = environment["SELENIUM_HOST"].to_s.strip

    unless selenium_host.empty?
      options[:allow] = lambda do |uri|
        uri.scheme == "http" && uri.host == selenium_host && uri.port == SELENIUM_PORT
      end
    end

    WebMock.disable_net_connect!(**options)
  end
end
