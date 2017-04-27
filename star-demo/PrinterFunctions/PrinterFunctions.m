//
//  PrinterFunctions.m
//  IOS_SDK
//
//  Created by Tzvi on 8/2/11.
//  Copyright 2011 - 2013 STAR MICRONICS CO., LTD. All rights reserved.
//

#import "PrinterFunctions.h"
#import <StarIO/SMPort.h>
#import <StarIO/SMBluetoothManager.h>
#import "RasterDocument.h"
#import "StarBitmap.h"
#import <sys/time.h>
#import <unistd.h>
#import <QuartzCore/QuartzCore.h>

@implementation PrinterFunctions

+ (SMPrinterType)parsePortSettings:(NSString *)portSettings {
    if (portSettings == nil) {
        return SMPrinterTypeDesktopPrinterStarLine;
    }
    
    NSArray *params = [portSettings componentsSeparatedByString:@";"];
    
    BOOL isESCPOSMode = NO;
    BOOL isPortablePrinter = NO;
    
    for (NSString *param in params) {
        NSString *str = [param stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
        
        if ([str caseInsensitiveCompare:@"mini"] == NSOrderedSame) {
            return SMPrinterTypePortablePrinterESCPOS;
        }
        
        if ([str caseInsensitiveCompare:@"Portable"] == NSOrderedSame) {
            isPortablePrinter = YES;
            continue;
        }
        
        if ([str caseInsensitiveCompare:@"escpos"] == NSOrderedSame) {
            isESCPOSMode = YES;
            continue;
        }
    }
    
    if (isPortablePrinter) {
        if (isESCPOSMode) {
            return SMPrinterTypePortablePrinterESCPOS;
        } else {
            return SMPrinterTypePortablePrinterStarLine;
        }
    }
    
    return SMPrinterTypeDesktopPrinterStarLine;
}

#pragma mark common

/**
 * This function is used to print a UIImage directly to the printer.
 * There are 2 ways a printer can usually print images, one is through raster commands the other is through line mode
 * commands.
 * This function uses raster commands to print an image. Raster is support on the tsp100 and all legacy thermal
 * printers. The line mode printing is not supported by the TSP100 so its not used
 *
 *  @param  portName        Port name to use for communication. This should be (TCP:<IP Address>), (BT:<iOS Port Name>),
 *                          or (BLE:<Device Name>).
 *  @param  portSettings    Set following settings
 *                          - Desktop USB Printer + Apple AirPort: @"9100" - @"9109" (Port Number)
 *                          - Portable Printer (Star Line Mode)  : @"portable"
 *                          - Others                             : @"" (blank)
 *  @param  source          The uiimage to convert to star raster data
 *  @param  maxWidth        The maximum with the image to print. This is usually the page with of the printer. If the
 *                          image exceeds the maximum width then the image is scaled down. The ratio is maintained.
 */
+ (NSString *)PrintImageWithPortname:(NSString *)portName
                  portSettings:(NSString *)portSettings
                  imageToPrint:(UIImage *)imageToPrint
                      maxWidth:(int)maxWidth
             compressionEnable:(BOOL)compressionEnable
                withDrawerKick:(BOOL)drawerKick
{
    NSMutableData *commandsToPrint = [NSMutableData new];
    
    SMPrinterType printerType = [self parsePortSettings:portSettings];
    StarBitmap *starbitmap = [[StarBitmap alloc] initWithUIImage:imageToPrint :maxWidth :false];
    
    if (printerType == SMPrinterTypeDesktopPrinterStarLine) {
        RasterDocument *rasterDoc = [[RasterDocument alloc] initWithDefaults:RasSpeed_Medium endOfPageBehaviour:RasPageEndMode_FeedAndFullCut endOfDocumentBahaviour:RasPageEndMode_FeedAndFullCut topMargin:RasTopMargin_Standard pageLength:0 leftMargin:0 rightMargin:0];
        
        NSData *shortcommand = [rasterDoc BeginDocumentCommandData];
        [commandsToPrint appendData:shortcommand];
        
        shortcommand = [starbitmap getImageDataForPrinting:compressionEnable];
        [commandsToPrint appendData:shortcommand];
        
        shortcommand = [rasterDoc EndDocumentCommandData];
        [commandsToPrint appendData:shortcommand];
        
        [rasterDoc release];
    } else if (printerType == SMPrinterTypePortablePrinterStarLine) {
        NSData *shortcommand = [starbitmap getGraphicsDataForPrinting:compressionEnable];
        [commandsToPrint appendData:shortcommand];
    } else {
        [commandsToPrint release];
        [starbitmap release];
        return @"Not found printerType";
    }
    
    [starbitmap release];

    // Kick Cash Drawer
    if (drawerKick == YES) {
        [commandsToPrint appendBytes:"\x07"
                              length:sizeof("\x07") - 1];
    }
    
    NSString *result = [self sendCommand:commandsToPrint portName:portName portSettings:portSettings timeoutMillis:10000];
    [commandsToPrint release];
    return result;
}

+ (NSString *)sendCommand:(NSData *)commandsToPrint
           portName:(NSString *)portName
       portSettings:(NSString *)portSettings
      timeoutMillis:(u_int32_t)timeoutMillis
{
    NSString *exceptionError = nil;
    int commandSize = (int)commandsToPrint.length;
    unsigned char *dataToSentToPrinter = (unsigned char *)malloc(commandSize);
    [commandsToPrint getBytes:dataToSentToPrinter length:commandSize];
    
    SMPort *starPort = nil;
    @try
    {
        starPort = [SMPort getPort:portName :portSettings :timeoutMillis];
        
        if (starPort == nil)
        {
            NSLog(@"====Fail to Open Port.\nRefer to \"getPort API\" in the manual.");
            return @"Fail to Open Port";
        }
        
        StarPrinterStatus_2 status;
        [starPort beginCheckedBlock:&status :2];
        if (status.offline == SM_TRUE) {
            NSLog(@"====Error : Printer is offline");
            return @"Error : Printer is offline";
        }
        
        struct timeval endTime;
        gettimeofday(&endTime, NULL);
        endTime.tv_sec += 30;
        
        int totalAmountWritten = 0;
        while (totalAmountWritten < commandSize)
        {
            int remaining = commandSize - totalAmountWritten;
            int amountWritten = [starPort writePort:dataToSentToPrinter :totalAmountWritten :remaining];
            totalAmountWritten += amountWritten;
            
            struct timeval now;
            gettimeofday(&now, NULL);
            if (now.tv_sec > endTime.tv_sec)
            {
                break;
            }
        }
        
        if (totalAmountWritten < commandSize)
        {
            NSLog(@"====Printer Error : Write port timed out");
            return @"Printer Error : Write port timed out";
        }
        
        starPort.endCheckedBlockTimeoutMillis = 30000;
        [starPort endCheckedBlock:&status :2];
        if (status.offline == SM_TRUE) {
            NSLog(@"====Error : Printer is offline");
            return @"Error : Printer is offline";
        }
    }
    @catch (PortException *exception)
    {
        NSLog(@"====Printer Error : Write port timed out");
        exceptionError = @"Printer Error : Write port timed out";
    }
    @finally
    {
        free(dataToSentToPrinter);
        [SMPort releasePort:starPort];
    }
    if(exceptionError != nil){
        return exceptionError;
    }
}
+ (NSArray *)SearchPrinter{
//    NSLog(@"test====>>");
    NSArray *devices = [[SMPort searchPrinter] retain];
//    NSLog(@"devices====: %@", devices);
//    for (int i = 0; i < devices.count; i++) {
//        PortInfo *port = [devices objectAtIndex:i];
//        NSLog(@"Port Name: %@", port.portName);
//        NSLog(@"MAC Address : %@", port.macAddress);
//        NSLog(@"Model Name: %@", port.modelName);
//    }
    NSMutableArray *posPrinters = [NSMutableArray new];
    
    //创建多个字典
    NSDictionary *test = [NSDictionary dictionaryWithObjectsAndKeys:
                          @"portName", @"portName",
                          @"macAddress", @"macAddress",
                          @"modelName", @"modelName",
                          nil];
//    NSLog(@"test====: %@", test);
    [posPrinters addObject:test];
    //创建多个字典
    NSDictionary *test1 = [NSDictionary dictionaryWithObjectsAndKeys:
                          @"portName", @"portName",
                          @"macAddress", @"macAddress",
                          @"modelName", @"modelName",
                          nil];
    //    NSLog(@"test====: %@", test);
    [posPrinters addObject:test1];
//    NSLog(@"posPrinters====: %@", posPrinters);
    for (PortInfo *port in devices) {
        [posPrinters addObject:port];
    }
    [devices release];
    return posPrinters;
}
@end
