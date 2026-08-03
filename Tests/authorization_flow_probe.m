#import <Foundation/Foundation.h>
#import "TGAuthorizationFlow.h"

static int TGAuthorizationFlowFailures = 0;

static void TGAuthAssert(BOOL condition, NSString *message) {
    if (!condition) {
        TGAuthorizationFlowFailures++;
        fprintf(stderr, "authorization_flow_probe: %s\n", [[message description] UTF8String]);
    }
}

static void TGTestStateDescriptors(void) {
    NSArray *states = [NSArray arrayWithObjects:
        @"waitPhoneNumber", @"waitEmailAddress", @"waitEmailCode",
        @"waitCode", @"waitRegistration", @"waitPassword", nil];
    NSUInteger index = 0;
    for (index = 0; index < [states count]; index++) {
        NSString *state = [states objectAtIndex:index];
        NSDictionary *descriptor = [TGAuthorizationFlow descriptorForState:state];
        TGAuthAssert([TGAuthorizationFlow isInputState:state], @"known state should accept input");
        TGAuthAssert([[descriptor objectForKey:TGAuthorizationFlowStateKey] isEqualToString:state],
                     @"descriptor should preserve the state");
        TGAuthAssert([[descriptor objectForKey:TGAuthorizationFlowTitleLocalizationKey] length] > 0,
                     @"descriptor should provide a title key");
    }
    TGAuthAssert(![TGAuthorizationFlow isInputState:@"ready"], @"ready state must not accept credentials");
    TGAuthAssert([[[TGAuthorizationFlow descriptorForState:@"waitPassword"] objectForKey:TGAuthorizationFlowSecureInputKey] boolValue],
                 @"password state must use secure input");
}

static void TGTestSafeStateDetails(void) {
    NSDictionary *codeInfo = [NSDictionary dictionaryWithObjectsAndKeys:
        [NSNumber numberWithInt:42], @"timeout",
        [NSNumber numberWithInt:6], @"length",
        [NSDictionary dictionaryWithObject:@"authenticationCodeTypeSms" forKey:@"@type"], @"next_type",
        nil];
    NSDictionary *state = [NSDictionary dictionaryWithObjectsAndKeys:
        @"authorizationStateWaitCode", @"@type",
        codeInfo, @"code_info",
        nil];
    NSDictionary *details = [TGAuthorizationFlow safeDetailsFromAuthorizationStateObject:state];
    TGAuthAssert([[details objectForKey:TGAuthorizationFlowStateKey] isEqualToString:@"waitCode"],
                 @"state fixture should be normalized");
    TGAuthAssert([[details objectForKey:@"resend_timeout"] integerValue] == 42,
                 @"resend timeout should be preserved");
    TGAuthAssert([[details objectForKey:@"code_length"] integerValue] == 6,
                 @"safe code length should be preserved");
    TGAuthAssert([[details objectForKey:@"can_resend"] boolValue],
                 @"next delivery type should enable resend");

    NSDictionary *emailState = [NSDictionary dictionaryWithObjectsAndKeys:
        @"authorizationStateWaitEmailCode", @"@type",
        [NSDictionary dictionaryWithObjectsAndKeys:@"m***@example.com", @"email_address_pattern",
                                                   [NSNumber numberWithInt:5], @"length", nil], @"code_info",
        nil];
    NSDictionary *emailDetails = [TGAuthorizationFlow safeDetailsFromAuthorizationStateObject:emailState];
    TGAuthAssert([[emailDetails objectForKey:@"email_pattern"] isEqualToString:@"m***@example.com"],
                 @"only Telegram's redacted email pattern should reach presentation");
    TGAuthAssert([[emailDetails objectForKey:@"can_resend"] boolValue],
                 @"email code state should support resend");
}

static void TGTestRequestPayloadHelpers(void) {
    NSError *error = nil;
    NSDictionary *names = [TGAuthorizationFlow registrationNamesFromCombinedInput:@"Ada Lovelace" error:&error];
    TGAuthAssert(names != nil && error == nil, @"valid registration name should parse");
    TGAuthAssert([[names objectForKey:@"first_name"] isEqualToString:@"Ada"], @"first name should be split safely");
    TGAuthAssert([[names objectForKey:@"last_name"] isEqualToString:@"Lovelace"], @"last name should be split safely");
    NSDictionary *emailCode = [TGAuthorizationFlow emailCodeAuthenticationObjectForCode:@"123456"];
    TGAuthAssert([[emailCode objectForKey:@"@type"] isEqualToString:@"emailAddressAuthenticationCode"],
                 @"modern email authentication object should be used");
    TGAuthAssert([[emailCode objectForKey:@"code"] isEqualToString:@"123456"],
                 @"email code helper should keep the submitted code only in the request object");
    TGAuthAssert([[[TGAuthorizationFlow resendCodeReasonObject] objectForKey:@"@type"]
                  isEqualToString:@"resendCodeReasonUserRequest"],
                 @"resend should identify an explicit user request");
}

int main(void) {
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    TGTestStateDescriptors();
    TGTestSafeStateDetails();
    TGTestRequestPayloadHelpers();
    if (TGAuthorizationFlowFailures == 0) {
        printf("Authorization flow probe passed.\n");
    }
    [pool drain];
    return TGAuthorizationFlowFailures == 0 ? 0 : 1;
}
