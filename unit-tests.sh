xcodebuild clean -workspace JinyanShaoFrenchInputMethod.xcworkspace/ -scheme Tests

xcodebuild test CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO -workspace JinyanShaoFrenchInputMethod.xcworkspace/ -scheme Tests
