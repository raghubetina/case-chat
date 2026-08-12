# Zeitwerk derives Responder::OpenAi from responder/open_ai.rb by default; the
# vendor spells it OpenAI, and so do we.
Rails.autoloaders.each do |autoloader|
  autoloader.inflector.inflect("open_ai" => "OpenAI")
end
