//
//  CreditsViewController.m
//  AudioWorks
//
//  Created by Jeff Gregorio on 6/24/15.
//  Copyright (c) 2015 Jeff Gregorio. All rights reserved.
//

#import "CreditsViewController.h"

@interface CreditsViewController ()

@end

@implementation CreditsViewController
@synthesize helpDisplayed;

- (void)viewDidLoad {

    [super viewDidLoad];

    // Initialize splash screen as a UIImageView
    creditsImageView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"splash_1024.png"]];
    [creditsImageView setFrame:[self view].frame];
    [[self view] addSubview:creditsImageView];
    
    helpDisplayed = false;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
