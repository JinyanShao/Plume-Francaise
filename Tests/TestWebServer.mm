#import "WebServer.h"
#import <XCTest/XCTest.h>

// These exercise the real GCDWebServer instance that main() already starts on
// localhost:62718 for the app-hosted test target, including the Origin check added
// to guard the preferences endpoints against CSRF from other localhost web pages.
@interface TestWebServer : XCTestCase
@end

@implementation TestWebServer

- (void)performRequest:(NSMutableURLRequest *)request statusCode:(NSInteger *)statusCode json:(NSDictionary **)json {
    [self performRequest:request statusCode:statusCode json:json timeout:5];
}

- (void)performRequest:(NSMutableURLRequest *)request
             statusCode:(NSInteger *)statusCode
                   json:(NSDictionary **)json
                timeout:(NSTimeInterval)timeout {
    XCTestExpectation *expectation = [self expectationWithDescription:@"http request"];
    __block NSInteger capturedStatus = 0;
    __block NSDictionary *capturedJSON = nil;
    NSURLSessionDataTask *task =
        [[NSURLSession sharedSession] dataTaskWithRequest:request
                                         completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
                                             capturedStatus = ((NSHTTPURLResponse *)response).statusCode;
                                             if (data.length > 0)
                                                 capturedJSON = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
                                             [expectation fulfill];
                                         }];
    [task resume];
    [self waitForExpectations:@[ expectation ] timeout:timeout];
    if (statusCode)
        *statusCode = capturedStatus;
    if (json)
        *json = capturedJSON;
}

- (NSMutableURLRequest *)requestWithPath:(NSString *)path method:(NSString *)method origin:(NSString *)origin body:(NSDictionary *)body {
    NSURL *url = [NSURL URLWithString:[@"http://localhost:62718" stringByAppendingString:path]];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    request.HTTPMethod = method;
    if (origin)
        [request setValue:origin forHTTPHeaderField:@"Origin"];
    if (body) {
        request.HTTPBody = [NSJSONSerialization dataWithJSONObject:body options:0 error:nil];
        [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    }
    return request;
}

- (void)testGetPreferenceSucceeds {
    NSInteger status = 0;
    NSDictionary *json = nil;
    [self performRequest:[self requestWithPath:@"/preference" method:@"GET" origin:nil body:nil] statusCode:&status json:&json];

    XCTAssertEqual(status, 200);
    XCTAssertNotNil(json[@"commitWordWithSpace"]);
}

- (void)testPostPreferenceWithMatchingOriginSucceeds {
    NSInteger status = 0;
    NSDictionary *json = nil;
    NSMutableURLRequest *request = [self requestWithPath:@"/preference"
                                                   method:@"POST"
                                                   origin:@"http://localhost:62718"
                                                     body:@{@"commitWordWithSpace" : @YES}];
    [self performRequest:request statusCode:&status json:&json];

    XCTAssertEqual(status, 200);
    XCTAssertEqualObjects(json[@"commitWordWithSpace"], @YES);
}

- (void)testPostPreferenceWithoutOriginIsForbidden {
    NSInteger status = 0;
    NSMutableURLRequest *request = [self requestWithPath:@"/preference" method:@"POST" origin:nil body:@{@"commitWordWithSpace" : @YES}];
    [self performRequest:request statusCode:&status json:nil];

    XCTAssertEqual(status, 403);
}

- (void)testPostPreferenceWithForeignOriginIsForbidden {
    NSInteger status = 0;
    NSMutableURLRequest *request = [self requestWithPath:@"/preference"
                                                   method:@"POST"
                                                   origin:@"http://evil.example"
                                                     body:@{@"commitWordWithSpace" : @YES}];
    [self performRequest:request statusCode:&status json:nil];

    XCTAssertEqual(status, 403);
}

- (void)testSubstitutionLifecycleRequiresTrustedOrigin {
    NSString *key = [NSString stringWithFormat:@"test-key-%@", @(arc4random())];

    NSInteger status = 0;
    NSMutableURLRequest *addWithoutOrigin = [self requestWithPath:@"/substitutions" method:@"POST" origin:nil body:@{@"key" : key, @"value" : @"test-value"}];
    [self performRequest:addWithoutOrigin statusCode:&status json:nil];
    XCTAssertEqual(status, 403);

    NSDictionary *afterRejectedAdd = nil;
    [self performRequest:[self requestWithPath:@"/substitutions" method:@"GET" origin:nil body:nil] statusCode:nil json:&afterRejectedAdd];
    XCTAssertNil(afterRejectedAdd[key], @"a rejected request must not have taken effect");

    NSDictionary *afterAdd = nil;
    NSMutableURLRequest *addWithOrigin = [self requestWithPath:@"/substitutions"
                                                         method:@"POST"
                                                         origin:@"http://localhost:62718"
                                                           body:@{@"key" : key, @"value" : @"test-value"}];
    [self performRequest:addWithOrigin statusCode:&status json:&afterAdd];
    XCTAssertEqual(status, 200);
    XCTAssertEqualObjects(afterAdd[key], @"test-value");

    NSMutableURLRequest *deleteWithoutOrigin = [self requestWithPath:[@"/substitutions/" stringByAppendingString:key] method:@"DELETE" origin:nil body:nil];
    [self performRequest:deleteWithoutOrigin statusCode:&status json:nil];
    XCTAssertEqual(status, 403);

    NSDictionary *afterDelete = nil;
    NSMutableURLRequest *deleteWithOrigin = [self requestWithPath:[@"/substitutions/" stringByAppendingString:key]
                                                             method:@"DELETE"
                                                             origin:@"http://localhost:62718"
                                                               body:nil];
    [self performRequest:deleteWithOrigin statusCode:&status json:&afterDelete];
    XCTAssertEqual(status, 200);
    XCTAssertNil(afterDelete[key]);
}

- (void)testUpdateCheckWithoutOriginIsForbidden {
    NSInteger status = 0;
    [self performRequest:[self requestWithPath:@"/update-check" method:@"POST" origin:nil body:nil] statusCode:&status json:nil];

    XCTAssertEqual(status, 403);
}

- (void)testUpdateCheckWithForeignOriginIsForbidden {
    NSInteger status = 0;
    NSMutableURLRequest *request = [self requestWithPath:@"/update-check" method:@"POST" origin:@"http://evil.example" body:nil];
    [self performRequest:request statusCode:&status json:nil];

    XCTAssertEqual(status, 403);
}

- (void)testUpdateCheckWithMatchingOriginReturnsVersionInfo {
    // Hits the real GitHub releases API, since that's the only network call this app
    // ever makes and it's worth verifying end-to-end rather than mocking it away.
    NSInteger status = 0;
    NSDictionary *json = nil;
    NSMutableURLRequest *request = [self requestWithPath:@"/update-check" method:@"POST" origin:@"http://localhost:62718" body:nil];
    [self performRequest:request statusCode:&status json:&json timeout:15];

    XCTAssertEqual(status, 200);
    XCTAssertTrue([json[@"currentVersion"] isKindOfClass:NSString.class]);
    XCTAssertTrue([json[@"latestVersion"] isKindOfClass:NSString.class]);
    XCTAssertTrue([json[@"releaseUrl"] isKindOfClass:NSString.class]);
    XCTAssertTrue([json[@"updateAvailable"] isKindOfClass:NSNumber.class]);
}

// The success path (a trusted-origin POST actually clearing word_selections) is
// intentionally not exercised here: this is the same file the shipped app's real learned
// data lives in when tests run on a machine that also has the app installed, and this
// suite runs before every commit, so a passing test would silently wipe real accumulated
// personalization on every run. The Origin check itself is the security-relevant behavior
// worth locking in; the DELETE statement it guards is covered by manual verification.
- (void)testResetLearnedSelectionsRequiresTrustedOrigin {
    NSInteger status = 0;
    [self performRequest:[self requestWithPath:@"/reset-learned-selections" method:@"POST" origin:nil body:nil] statusCode:&status json:nil];
    XCTAssertEqual(status, 403);

    NSInteger foreignStatus = 0;
    NSMutableURLRequest *request = [self requestWithPath:@"/reset-learned-selections" method:@"POST" origin:@"http://evil.example" body:nil];
    [self performRequest:request statusCode:&foreignStatus json:nil];
    XCTAssertEqual(foreignStatus, 403);
}

@end
