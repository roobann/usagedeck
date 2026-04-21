cask "usage-deck" do
  version "__VERSION__"
  sha256 "__SHA256__"

  url "https://github.com/roobann/usagedeck/releases/download/v#{version}/UsageDeck-#{version}.zip"
  name "Usage Deck"
  desc "Menu bar AI usage monitor"
  homepage "https://github.com/roobann/usagedeck"

  app "Usage Deck.app"

  zap trash: [
    "~/Library/Application Support/com.usagedeck.app",
    "~/Library/Preferences/com.usagedeck.app.plist",
  ]
end
