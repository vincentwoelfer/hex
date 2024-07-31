# HEX

## Tips
- Variables in @tool scripts (like HexConst) are ephemeral. They get set to the value in the script on editor start an can be changed via code (e.g. HexConstModifier). They will be lost (= reset to the value specified in code) upon editor restart. Modify them for testing but safe the correct values somewhere!
