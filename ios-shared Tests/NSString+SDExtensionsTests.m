//
//  NSString+SDExtensionsTests.m
//  ios-shared-Tests
//
//  Created by Steven Woolgar on 11/25/2013.
//  Copyright (c) 2013 SetDirection. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "NSString+SDExtensions.h"

@interface NSStringTests : XCTestCase
{
    CGFloat _red;
    CGFloat _green;
    CGFloat _blue;
    CGFloat _alpha;
}

@end

@implementation NSStringTests

- (void)setUp
{
    [super setUp];

    _red = 0.0f;
    _green = 0.0f;
    _blue = 0.0f;
    _alpha = 0.0f;
}

- (void)tearDown
{
    // Tear-down code here.
    
    [super tearDown];
}

- (void)testNSStringNilUIColor
{
    UIColor* lazyWhiteNoAlpha = [@"#fff" uicolor];
    XCTAssertTrue(lazyWhiteNoAlpha != nil, @"A valid color should have been returned.");
}

- (void)testNSStringLazyUIColor
{
    UIColor* lazyWhiteNoAlpha = [@"#fff" uicolor];
    [lazyWhiteNoAlpha getRed:&_red green:&_green blue:&_blue alpha:&_alpha];
    XCTAssertTrue(_red == 255.0f / 255.0f && _green == 255.0f / 255.0f & _blue == 255.0f / 255.0f & _alpha == 255.0f / 255.0f, @"#fff returned the wrong value.");
}

- (void)testNSStringGreenUIColor
{
    UIColor* greenNoAlpha = [@"#112233" uicolor];
    [greenNoAlpha getRed:&_red green:&_green blue:&_blue alpha:&_alpha];
    XCTAssertTrue(_red == 17.0f / 255.0f && _green == 34.0f / 255.0f & _blue == 51.0f / 255.0f & _alpha == 255.0f / 255.0f, @"#112233 returned the wrong value.");
}

- (void)testNSStringGreenWithAlphaUIColor
{
    UIColor* greenWithAlpha = [@"#11223344" uicolor];
    [greenWithAlpha getRed:&_red green:&_green blue:&_blue alpha:&_alpha];
    XCTAssertTrue(_red == 17.0f / 255.0f && _green == 34.0f / 255.0f & _blue == 51.0f / 255.0f & _alpha == 68.0f / 255.0f, @"#11223344 returned the wrong value.");
}

- (void)testNSStringInvalidUIColor
{
    CGFloat whiteRed = 0.0f;
    CGFloat whiteGreen = 0.0f;
    CGFloat whiteBlue = 0.0f;
    CGFloat whiteAlpha = 0.0f;
    UIColor* white = [UIColor whiteColor];
    [white getRed:&whiteRed green:&whiteGreen blue:&whiteBlue alpha:&whiteAlpha];

    UIColor* invalidHexNoAlpha = [@"#1" uicolor];
    [invalidHexNoAlpha getRed:&_red green:&_green blue:&_blue alpha:&_alpha];
    XCTAssertTrue(_red == whiteRed && _green == whiteGreen && _blue == whiteBlue & _alpha == whiteAlpha, @"A valid white color should have been returned.");
}

- (void)testCapitalizedStreetAddressString
{
    NSString* source = @"2417 NE 11th Ave. 1234 SW 3rd Ave. 321 SE 1st Street. 234 NW 2nd Street.";
    NSString* changed = [source capitalizedStreetAddressString];

    XCTAssertTrue([source isEqualToString:changed], @"The capitalizeStreetAddress method did not properly capitalize.");
}

@end
