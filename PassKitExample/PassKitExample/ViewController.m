//
//  ViewController.m
//  PassKitExample
//
//  Created by niyongsheng on 2023/8/9.
//

#import "ViewController.h"
#import <PassKit/PassKit.h>
#import <PassKit/PKAddPaymentPassRequest.h>
#import <PassKit/PKAddPaymentPassViewController.h>

@import CoreNFC;

@interface ViewController ()
<
NFCNDEFReaderSessionDelegate,
PKAddPassesViewControllerDelegate,
PKAddPaymentPassViewControllerDelegate
>

@property (nonatomic, strong) NFCNDEFReaderSession *session;
@property (nonatomic, strong) NFCNDEFReaderSession *alert;

@property (nonatomic, weak) IBOutlet UIButton *scanButton;
@property (nonatomic, weak) IBOutlet UIButton *writeButton;
@property (nonatomic, weak) IBOutlet UITextView *logView;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.logView.layer.cornerRadius = 7.5f;
    self.logView.layer.borderWidth  = 1.5f;
    self.logView.layer.borderColor  = UIColor.lightGrayColor.CGColor;
    
    PKAddPassButton *pkAddBtn = [[PKAddPassButton alloc] initWithAddPassButtonStyle:PKAddPassButtonStyleBlack];
    pkAddBtn.titleLabel.font = [UIFont systemFontOfSize:12];
    CGFloat w = [[UIScreen mainScreen] bounds].size.width;
    pkAddBtn.frame = CGRectMake(100, 60*w/375.0, 220, 40);
    [pkAddBtn addTarget:self action:@selector(pkAddBtnClick:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:pkAddBtn];
}

#pragma mark - NFCNDEFReaderSessionDelegate
- (void)readerSession:(nonnull NFCNDEFReaderSession *)session didInvalidateWithError:(nonnull NSError *)error {
    NSLog(@"Error: %@", [error debugDescription]);
    
    if (error.code == NFCReaderSessionInvalidationErrorUserCanceled) {
        // User cancellation.
        return;
    }
    
    [self outputLog:error];
}

- (void)readerSession:(nonnull NFCNDEFReaderSession *)session didDetectNDEFs:(nonnull NSArray<NFCNDEFMessage *> *)messages {
    for (NFCNDEFMessage *message in messages) {
        for (NFCNDEFPayload *payload in message.records) {
            NSLog(@"Payload: %@", payload);
            const NSDate *date = [NSDate date];
            dispatch_async(dispatch_get_main_queue(), ^{
                self.logView.text = [NSString stringWithFormat:
                                     @"[%@] Identifier: %@ (%@)\n"
                                     @"[%@] Type: %@ (%@)\n"
                                     @"[%@] Format: %d\n"
                                     @"[%@] Payload: %@ (%@)\n%@",
                                     date,
                                     payload.identifier,
                                     [[NSString alloc] initWithData:payload.identifier
                                                           encoding:NSASCIIStringEncoding],
                                     date,
                                     payload.type,
                                     [[NSString alloc] initWithData:payload.type
                                                           encoding:NSASCIIStringEncoding],
                                     date,
                                     payload.typeNameFormat,
                                     date,
                                     payload.payload,
                                     [[NSString alloc] initWithData:payload.payload
                                                           encoding:NSASCIIStringEncoding],
                                     self.logView.text];
            });
        }
    }
}

#pragma mark - Methods
- (void)pkAddBtnClick:(PKAddPassButton *)button {
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    dispatch_async(queue, ^{
        NSString *filePath = [[NSBundle mainBundle] pathForResource:@"walletCard" ofType:@"pkpass"];
        NSError *error = nil;
        PKPass *pass = [[PKPass alloc] initWithData:[NSData dataWithContentsOfFile:filePath] error:&error];
        if (error) {
            NSLog(@"Error: %@", [error debugDescription]);
            [self outputLog:error];
            return;
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            PKAddPassesViewController *pkAddPassesViewController = [[PKAddPassesViewController alloc] initWithPass:pass];
            pkAddPassesViewController.delegate = self;
            [self presentViewController:pkAddPassesViewController animated:YES completion:nil];
        });
    });
}

- (void)outputLog:(NSError *)error {
    dispatch_async(dispatch_get_main_queue(), ^{
        self.logView.text = [NSString stringWithFormat:@"[%@] %@: %@ (%ld)\n%@",
                             [NSDate date],
                             error.code == 0 ? @"Info" : @"Error",
                             [error localizedDescription],
                             error.code,
                             self.logView.text];
    });
}

- (void)setupAlertVc:(NSString *)message {
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"Tips" message:message preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction *okAction = [UIAlertAction actionWithTitle:@"ok" style:UIAlertActionStyleDefault handler:nil];
    [alertController addAction:okAction];
    [self presentViewController:alertController animated:YES completion:nil];
}

- (void)beginSession {
    self.session = [[NFCNDEFReaderSession alloc] initWithDelegate:self queue:dispatch_queue_create(NULL, DISPATCH_QUEUE_CONCURRENT) invalidateAfterFirstRead:NO];
    [self.session beginSession];
}

#pragma mark - IBActions
- (IBAction)scan:(UIButton *)sender {
    [self beginSession];
}

- (IBAction)write:(UIButton *)sender {
    PKAddPaymentPassRequestConfiguration *config = [[PKAddPaymentPassRequestConfiguration alloc] initWithEncryptionScheme:PKEncryptionSchemeECC_V2];
    if (@available(iOS 12.0, *)) {
        config.style = PKAddPaymentPassStyleAccess;
    }
    config.cardholderName = @"ARPA 倪永胜";
    config.primaryAccountSuffix = @"01070252";
    config.localizedDescription = @"软件定义物流 数字改变生活";
    PKAddPaymentPassViewController *pkapVC = [[PKAddPaymentPassViewController alloc] initWithRequestConfiguration:config delegate:self];
    if (!pkapVC) {
        [self setupAlertVc:@"Please check permissions:\n'com.apple.developer.payment-pass-provisioning'"];
        return;
    }
    [self presentViewController:pkapVC animated:YES completion:nil];
}

- (IBAction)clear:(UIButton *)sender {
    self.logView.text = @"";
}

#pragma mark - PKAddPassesViewControllerDelegate
-(void)addPassesViewControllerDidFinish:(PKAddPassesViewController *)controller {
    [controller dismissViewControllerAnimated:true completion:^{
        NSDictionary *info = @{NSLocalizedDescriptionKey : @"add pass finished."};
        NSError *error = [NSError errorWithDomain:NSCocoaErrorDomain code:0 userInfo:info];
        [self outputLog:error];
    }];
}

#pragma mark - PKAddPaymentPassViewControllerDelegate
- (void)addPaymentPassViewController:(PKAddPaymentPassViewController *)controller
 generateRequestWithCertificateChain:(NSArray<NSData *> *)certificates
                               nonce:(NSData *)nonce
                      nonceSignature:(NSData *)nonceSignature
                   completionHandler:(void(^)(PKAddPaymentPassRequest *request))handler {
    
    PKAddPaymentPassRequest *paymentPassRequest = [[PKAddPaymentPassRequest alloc] init];
    paymentPassRequest.encryptedPassData = [[NSData alloc] initWithBase64EncodedString:@"123456" options:0];
    paymentPassRequest.activationData = [@"84DBC649D00804000320D03B5B81391D" dataUsingEncoding:NSUTF8StringEncoding];
    paymentPassRequest.ephemeralPublicKey = [[NSData alloc] initWithBase64EncodedString:@"0x9422d67f6a13fd62e1adf22207b3a99f5e6051d1c2d981b32f7d0de7672a1b18" options:0];
    
    handler(paymentPassRequest);
}

- (void)addPaymentPassViewController:(PKAddPaymentPassViewController *)controller didFinishAddingPaymentPass:(nullable PKPaymentPass *)pass error:(nullable NSError *)error {
    NSLog(@"Error: %@", [error debugDescription]);
    [self outputLog:error];
}

- (void)dealloc {
    [self.session invalidateSession];
}

@end
