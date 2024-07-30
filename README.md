# HEX

## Tips
- Variables in @tool scripts (like HexConstants) are ephemeral. They get set to the value in the script on editor start an can be changed via code (e.g. HexConstantsModifier). They will be lost (= reset to the value specified in code) upon editor restart. Modify them for testing but safe the correct values somewhere!
