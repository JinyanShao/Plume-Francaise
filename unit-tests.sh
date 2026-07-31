xcodebuild clean -workspace PlumeFrancaise.xcworkspace/ -scheme Tests

xcodebuild test CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO -workspace PlumeFrancaise.xcworkspace/ -scheme Tests
