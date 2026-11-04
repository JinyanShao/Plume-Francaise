#import "WebServer.h"
#import <XCTest/XCTest.h>

@interface WebServer (UpdateTest)
@property(atomic, strong) NSURLSessionConfiguration *updateSessionConfiguration;
@end

static NSInteger stubStatus;
static NSData *stubData;
static NSError *stubError;

@interface UpdateURLProtocol : NSURLProtocol
@end

@implementation UpdateURLProtocol
+ (BOOL)canInitWithRequest:(NSURLRequest *)request { return YES; }
+ (NSURLRequest *)canonicalRequestForRequest:(NSURLRequest *)request { return request; }
- (void)startLoading {
    if (stubError) {
        [self.client URLProtocol:self didFailWithError:stubError];
    } else {
        NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:self.request.URL
                                                                statusCode:stubStatus
                                                               HTTPVersion:@"HTTP/1.1"
                                                              headerFields:nil];
        [self.client URLProtocol:self didReceiveResponse:response cacheStoragePolicy:NSURLCacheStorageNotAllowed];
        [self.client URLProtocol:self didLoadData:stubData];
        [self.client URLProtocolDidFinishLoading:self];
    }
}
- (void)stopLoading {}
@end

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

- (void)tearDown {
    [WebServer sharedServer].updateSessionConfiguration = nil;
    stubData = nil;
    stubError = nil;
    [super tearDown];
}

- (void)stubUpdateResponse:(NSString *)body status:(NSInteger)status error:(NSError *)error {
    stubStatus = status;
    stubData = [body dataUsingEncoding:NSUTF8StringEncoding];
    stubError = error;
    NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration ephemeralSessionConfiguration];
    configuration.protocolClasses = @[ UpdateURLProtocol.class ];
    [WebServer sharedServer].updateSessionConfiguration = configuration;
}

- (void)performUpdateCheckWithStatus:(NSInteger *)status json:(NSDictionary **)json {
    NSMutableURLRequest *request = [self requestWithPath:@"/update-check" method:@"POST" origin:@"http://localhost:62718" body:nil];
    [self performRequest:request statusCode:status json:json];
}

- (void)testUpdateCheckWithMatchingOriginReturnsVersionInfo {
    [self stubUpdateResponse:@"{\"tag_name\":\"v9999.2.3\",\"html_url\":\"https://example.com/release\"}" status:200 error:nil];
    NSInteger status = 0;
    NSDictionary *json = nil;
    [self performUpdateCheckWithStatus:&status json:&json];

    XCTAssertEqual(status, 200);
    XCTAssertTrue([json[@"currentVersion"] isKindOfClass:NSString.class]);
    XCTAssertEqualObjects(json[@"latestVersion"], @"9999.2.3");
    XCTAssertEqualObjects(json[@"releaseUrl"], @"https://example.com/release");
    XCTAssertEqualObjects(json[@"updateAvailable"], @YES);
}

- (void)testUpdateCheckTimeoutReturnsServiceUnavailable {
    NSError *error = [NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorTimedOut userInfo:nil];
    [self stubUpdateResponse:@"" status:0 error:error];
    NSInteger status = 0;
    [self performUpdateCheckWithStatus:&status json:nil];
    XCTAssertEqual(status, 503);
}

- (void)testUpdateCheckNon200ReturnsServiceUnavailable {
    [self stubUpdateResponse:@"{\"tag_name\":\"v9999.2.3\"}" status:403 error:nil];
    NSInteger status = 0;
    [self performUpdateCheckWithStatus:&status json:nil];
    XCTAssertEqual(status, 503);
}

- (void)testUpdateCheckMalformedResponsesReturnServiceUnavailable {
    for (NSString *body in @[ @"not json", @"[]", @"{}", @"{\"tag_name\":\"\"}" ]) {
        [self stubUpdateResponse:body status:200 error:nil];
        NSInteger status = 0;
        [self performUpdateCheckWithStatus:&status json:nil];
        XCTAssertEqual(status, 503, @"body: %@", body);
    }
}

- (void)testUpdateCheckHandlesMissingReleaseURL {
    [self stubUpdateResponse:@"{\"tag_name\":\"v0.0.0\",\"html_url\":42}" status:200 error:nil];
    NSInteger status = 0;
    NSDictionary *json = nil;
    [self performUpdateCheckWithStatus:&status json:&json];
    XCTAssertEqual(status, 200);
    XCTAssertEqualObjects(json[@"releaseUrl"], @"https://github.com/JinyanShao/Plume-Francaise/releases");
    XCTAssertEqualObjects(json[@"updateAvailable"], @NO);
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
