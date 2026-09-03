#import "WebServer.h"
#import "ConversionEngine.h"
#import "GCDWebServer.h"
#import "GCDWebServerDataRequest.h"
#import "GCDWebServerDataResponse.h"
#import "GCDWebServerErrorResponse.h"

extern NSUserDefaults *preference;
extern ConversionEngine *engine;

NSString *COMMIT_WORD_WITH_SPACE_KEY = @"commitWordWithSpace";

@interface WebServer ()

@property(nonatomic, strong) GCDWebServer *server;

@end

@implementation WebServer

static int port = 62718;

// The preferences page is only ever served from this same loopback origin. Any request
// that changes state must present a matching Origin header, or it is rejected. Browsers
// attach Origin to every same-origin fetch that isn't a plain GET/HEAD, as well as to
// cross-site requests (including plain HTML form submissions), so this reliably tells
// apart our own page from a malicious site trying to drive the preferences server via
// the user's browser (CSRF / DNS-rebinding style attacks against localhost services).
static BOOL RequestHasTrustedOrigin(GCDWebServerRequest *request) {
    NSString *origin = request.headers[@"Origin"];
    if (origin.length == 0)
        return NO;
    NSString *expectedOrigin = [NSString stringWithFormat:@"http://localhost:%d", port];
    return [origin caseInsensitiveCompare:expectedOrigin] == NSOrderedSame;
}

// Compares two "vX.Y.Z"-ish version strings component by component. Returns YES if
// `latest` is strictly newer than `current`. Missing or non-numeric components are
// treated as 0, so this degrades gracefully instead of throwing on unexpected input.
static BOOL VersionIsNewer(NSString *latest, NSString *current) {
    NSCharacterSet *nonDigits = [NSCharacterSet characterSetWithCharactersInString:@"0123456789."];
    NSString *cleanLatest = [[latest componentsSeparatedByCharactersInSet:nonDigits.invertedSet] componentsJoinedByString:@""];
    NSArray<NSString *> *latestParts = [cleanLatest componentsSeparatedByString:@"."];
    NSArray<NSString *> *currentParts = [current componentsSeparatedByString:@"."];
    NSUInteger count = MAX(latestParts.count, currentParts.count);
    for (NSUInteger i = 0; i < count; i++) {
        NSInteger latestValue = i < latestParts.count ? latestParts[i].integerValue : 0;
        NSInteger currentValue = i < currentParts.count ? currentParts[i].integerValue : 0;
        if (latestValue != currentValue)
            return latestValue > currentValue;
    }
    return NO;
}

+ (instancetype)sharedServer {
    static WebServer *server = nil;
    static dispatch_once_t token;
    dispatch_once(&token, ^{
        server = [[WebServer alloc] init];
    });
    return server;
}

- (void)start {
    if (self.server) {
        return;
    }

    GCDWebServer *webServer = [[GCDWebServer alloc] init];
    [webServer addGETHandlerForBasePath:@"/"
                          directoryPath:[NSString stringWithFormat:@"%@/%@", [NSBundle mainBundle].resourcePath, @"web"]
                          indexFilename:nil
                               cacheAge:3600
                     allowRangeRequests:YES];

    [webServer addHandlerForMethod:@"GET"
                              path:@"/preference"
                      requestClass:[GCDWebServerRequest class]
                      processBlock:^GCDWebServerResponse *(GCDWebServerRequest *request) {
                          return [GCDWebServerDataResponse responseWithJSONObject:@{
                              COMMIT_WORD_WITH_SPACE_KEY : @([preference boolForKey:COMMIT_WORD_WITH_SPACE_KEY])
                          }];
                      }];

    [webServer addHandlerForMethod:@"POST"
                              path:@"/preference"
                      requestClass:[GCDWebServerDataRequest class]
                      processBlock:^GCDWebServerResponse *(GCDWebServerRequest *request) {
                          if (!RequestHasTrustedOrigin(request))
                              return [GCDWebServerErrorResponse responseWithClientError:kGCDWebServerHTTPStatusCode_Forbidden
                                                                                message:@"Untrusted origin"];

                          NSDictionary *data = ((GCDWebServerDataRequest *)request).jsonObject;

                          bool commitWordWithSpace = [data[COMMIT_WORD_WITH_SPACE_KEY] boolValue];
                          [preference setBool:commitWordWithSpace forKey:COMMIT_WORD_WITH_SPACE_KEY];

                          return [GCDWebServerDataResponse responseWithJSONObject:data];
                      }];

    [webServer addHandlerForMethod:@"GET"
                              path:@"/substitutions"
                      requestClass:[GCDWebServerRequest class]
                      processBlock:^GCDWebServerResponse *(GCDWebServerRequest *request) {
                          return [GCDWebServerDataResponse responseWithJSONObject:[engine allSubstitutions]];
                      }];

    [webServer addHandlerForMethod:@"POST"
                              path:@"/substitutions"
                      requestClass:[GCDWebServerDataRequest class]
                      processBlock:^GCDWebServerResponse *(GCDWebServerRequest *request) {
                          if (!RequestHasTrustedOrigin(request))
                              return [GCDWebServerErrorResponse responseWithClientError:kGCDWebServerHTTPStatusCode_Forbidden
                                                                                message:@"Untrusted origin"];

                          NSDictionary *data = ((GCDWebServerDataRequest *)request).jsonObject;
                          NSString *key = data[@"key"];
                          NSString *value = data[@"value"];
                          if (key.length > 0 && value.length > 0) {
                              [engine addSubstitution:key value:value];
                          }
                          return [GCDWebServerDataResponse responseWithJSONObject:[engine allSubstitutions]];
                      }];

    [webServer addHandlerForMethod:@"DELETE"
                         pathRegex:@"/substitutions/(.+)"
                      requestClass:[GCDWebServerRequest class]
                      processBlock:^GCDWebServerResponse *(GCDWebServerRequest *request) {
                          if (!RequestHasTrustedOrigin(request))
                              return [GCDWebServerErrorResponse responseWithClientError:kGCDWebServerHTTPStatusCode_Forbidden
                                                                                message:@"Untrusted origin"];

                          NSArray *captures = [request attributeForKey:GCDWebServerRequestAttribute_RegexCaptures];
                          NSString *key = captures.firstObject;
                          if (key.length > 0) {
                              [engine removeSubstitution:key];
                          }
                          return [GCDWebServerDataResponse responseWithJSONObject:[engine allSubstitutions]];
                      }];

    // The only network request this app ever makes, and only when the user clicks
    // "Check for updates" in the preferences page. Nothing is sent besides the plain
    // HTTPS request GitHub's public releases API requires; no identifying data is included.
    // POST (not GET) so browsers attach an Origin header we can check: fetch() only sends
    // Origin on non-GET/HEAD requests, even for same-origin calls.
    [webServer addHandlerForMethod:@"POST"
                                path:@"/update-check"
                        requestClass:[GCDWebServerRequest class]
                   asyncProcessBlock:^(GCDWebServerRequest *request, GCDWebServerCompletionBlock completionBlock) {
                       if (!RequestHasTrustedOrigin(request)) {
                           completionBlock([GCDWebServerErrorResponse responseWithClientError:kGCDWebServerHTTPStatusCode_Forbidden
                                                                                       message:@"Untrusted origin"]);
                           return;
                       }
                       NSString *currentVersion = [NSBundle mainBundle].infoDictionary[@"CFBundleShortVersionString"] ?: @"0";
                       NSURL *url = [NSURL URLWithString:@"https://api.github.com/repos/JinyanShao/Plume-Francaise/releases/latest"];
                       NSMutableURLRequest *githubRequest = [NSMutableURLRequest requestWithURL:url];
                       [githubRequest setValue:@"application/vnd.github+json" forHTTPHeaderField:@"Accept"];
                       NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration ephemeralSessionConfiguration];
                       configuration.timeoutIntervalForRequest = 8;
                       NSURLSession *session = [NSURLSession sessionWithConfiguration:configuration];
                       NSURLSessionDataTask *task = [session
                           dataTaskWithRequest:githubRequest
                             completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
                                 if (error || data.length == 0) {
                                     completionBlock([GCDWebServerErrorResponse
                                         responseWithServerError:kGCDWebServerHTTPStatusCode_ServiceUnavailable
                                                          message:@"Could not reach GitHub: %@", error.localizedDescription ?: @"empty response"]);
                                     return;
                                 }
                                 NSDictionary *release = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
                                 NSString *tagName = release[@"tag_name"];
                                 if (![tagName isKindOfClass:NSString.class]) {
                                     completionBlock([GCDWebServerErrorResponse
                                         responseWithServerError:kGCDWebServerHTTPStatusCode_ServiceUnavailable
                                                          message:@"Unexpected response from GitHub"]);
                                     return;
                                 }
                                 NSString *latestVersion = [tagName hasPrefix:@"v"] ? [tagName substringFromIndex:1] : tagName;
                                 NSString *releaseUrl = release[@"html_url"];
                                 completionBlock([GCDWebServerDataResponse responseWithJSONObject:@{
                                     @"currentVersion" : currentVersion,
                                     @"latestVersion" : latestVersion,
                                     @"updateAvailable" : @(VersionIsNewer(latestVersion, currentVersion)),
                                     @"releaseUrl" : releaseUrl ?: @"https://github.com/JinyanShao/Plume-Francaise/releases",
                                 }]);
                             }];
                       [task resume];
                   }];

    NSMutableDictionary *options = [NSMutableDictionary dictionary];
    options[GCDWebServerOption_Port] = @(port);
    options[GCDWebServerOption_BindToLocalhost] = @YES;

    NSError *error = nil;
    if (![webServer startWithOptions:options error:&error]) {
        NSLog(@"[PlumeFrancaise] Failed to start preferences server on port %d: %@", port, error);
        return;
    }

    self.server = webServer;
}

@end
