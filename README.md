# Use Caps Lock to switch input language on macOS more reliably than System Settings

This is a simple macOS application that allows you to switch the input language of your Mac using the Caps Lock key on Key Down event, so it works more reliably.

The problem with System Setting ("Keyboard Modifiers") is that it's working on Caps Lock being released, which means that if you are too fast and press Caps Lock with another key, it will not work. Sometimes it won't work even if you press Caps Lock correctly. No idea how (and when) it works.

The system way is way too unpredictable, it will work sometimes and not work sometimes.

Previously, I used Karabiner Elements, but on latest macOS it has some weird bugs (like Cmd+` not swithing same app windows for some reason).

I decided to make my own app. I don't know Swift, so I used AI to make this.

**Warning: code for this app was written by AI, I'm not a Swift developer, so use it at your own risk.  Works for me, all that I can say.**

(Interestingly, Claude 3.5 Sonnet mostly failed to generate the working code, even though it created a good base. o3-mini did a good job after a few hours of pushing it towards the right direction.)

## How to build and run

You probably need Xcode CLI tools to build it. Install them with `xcode-select --install`.

```bash
git clone https://github.com/slava-vishnyakov/CapsLangSwitch
cd CapsLangSwitch
./build.sh
mv CapsLangSwitch.app /Applications/
```

Then run Caps Lang Switch from Applications, give it the Accessibility permission (it will open System Preferences for you), and enjoy!