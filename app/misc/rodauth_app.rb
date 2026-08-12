class RodauthApp < Rodauth::Rails::App
  configure RodauthMain

  route do |request|
    rodauth.load_memory
    request.rodauth
  end
end
