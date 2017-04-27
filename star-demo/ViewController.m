//
//  ViewController.m
//  star-demo
//
//  Created by 晁荣 on 2017/4/27.
//  Copyright © 2017年 maichong. All rights reserved.
//

#import "ViewController.h"
#import "PrinterFunctions.h"
#import <StarIO/SMPort.h>

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    CGFloat kSpacing = 10;
    CGFloat imageY = kSpacing;
    NSArray *portArray = [[PrinterFunctions SearchPrinter] retain];
    CGFloat imageWidth = ceilf( 30 * 10);
    CGFloat imageHeight = ceilf( 50 * 10);
    CGSize imageSize = CGSizeMake( imageWidth, imageHeight );
    //    imageY += imageHeight + kSpacing;
    UITextView *textView = [[[UITextView alloc] initWithFrame:CGRectMake(0, imageY, imageSize.width, imageSize.height)] autorelease]; //初始化大小并自动释放
    textView.textColor = [UIColor blackColor];//设置textview里面的字体颜色
    textView.font = [UIFont fontWithName:@"Arial" size:18.0];//设置字体名字和字体大小
    textView.backgroundColor = [UIColor whiteColor];//设置它的背景颜色
    textView.autoresizingMask = UIViewAutoresizingFlexibleHeight;//自适应高度
    NSString *tempString = [portArray componentsJoinedByString:@","];
    textView.text = tempString;//设置它显示的内容
    [self.view addSubview:textView];//加入到整个页面中
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


@end
