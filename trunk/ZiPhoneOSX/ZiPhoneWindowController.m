//
//  ZiPhoneWindowController.m
//  ZiPhoneOSX
//

#import "ZiPhoneWindowController.h"

#define is_digit(c) ((unsigned)((c) - '0') <= 9)

#define PMT_NORMAL 1
#define PMT_ERROR 2
#define PMT_SUCCESS 3

#define NOSHOWIF_KEY @"NOSHOWIF"
#define ONLYSHOWIF_KEY @"ONLYSHOWIF"

@implementation ZiPhoneWindowController

/**
 * Handle initilization once the GUI is loaded.
 */
- (void)awakeFromNib {
  [self checkboxClicked:self];
  [m_btnStop setEnabled:NO];
  
  m_dctButtonStates = [[NSDictionary dictionaryWithObjectsAndKeys: 
                        
                        [NSDictionary dictionaryWithObjectsAndKeys:
                         //[NSArray arrayWithObjects: nil], NOSHOWIF_KEY,
                         //[NSArray arrayWithObjects: nil], ONLYSHOWIF_KEY,
                         nil], [NSNumber numberWithInt:[m_btnJailbreak tag]],
                        
                        [NSDictionary dictionaryWithObjectsAndKeys:
                         //[NSArray arrayWithObjects: nil], NOSHOWIF_KEY,
                         //[NSArray arrayWithObjects: nil], ONLYSHOWIF_KEY,
                         nil], [NSNumber numberWithInt:[m_btnActivate tag]],
                        
                        [NSDictionary dictionaryWithObjectsAndKeys:
                         [NSArray arrayWithObjects:  m_btnDowngrade, m_btnErase, nil], NOSHOWIF_KEY,
                         //[NSArray arrayWithObjects: nil], ONLYSHOWIF_KEY,
                         nil], [NSNumber numberWithInt:[m_btnUnlock tag]],
                                              
                        [NSDictionary dictionaryWithObjectsAndKeys:
                         [NSArray arrayWithObjects: m_btnDowngrade, m_btnErase, nil], NOSHOWIF_KEY,
                         //[NSArray arrayWithObjects: m_btnUnlock, nil], ONLYSHOWIF_KEY,
                         nil], [NSNumber numberWithInt:[m_btnChangeImei tag]],
                        
                        [NSDictionary dictionaryWithObjectsAndKeys:
                         //[NSArray arrayWithObjects: nil], NOSHOWIF_KEY,
                         [NSArray arrayWithObjects: m_btnChangeImei, nil], ONLYSHOWIF_KEY,
                         nil], [NSNumber numberWithInt:[m_txtImei tag]],
                        
                        [NSDictionary dictionaryWithObjectsAndKeys:
                         [NSArray arrayWithObjects:  m_btnDowngrade, m_btnUnlock, m_btnChangeImei, nil], NOSHOWIF_KEY,
                         //[NSArray arrayWithObjects: nil], ONLYSHOWIF_KEY,
                         nil], [NSNumber numberWithInt:[m_btnErase tag]],
                        
                        [NSDictionary dictionaryWithObjectsAndKeys:
                         [NSArray arrayWithObjects:  m_btnErase, m_btnUnlock, m_btnChangeImei, nil], NOSHOWIF_KEY,
                         //[NSArray arrayWithObjects: nil], ONLYSHOWIF_KEY,
                         nil], [NSNumber numberWithInt:[m_btnDowngrade tag]],                        
                        
                        nil
                       ] retain];
  
  
    m_arControls = [[NSArray arrayWithObjects:m_btnDowngrade, m_btnUnlock, m_btnActivate, m_btnJailbreak, 
                  m_btnChangeImei, m_btnErase, m_txtImei, nil] retain];
  }

- (void)dealloc {
  [m_processTask release];
  m_processTask = nil;

  [m_dctButtonStates release];
  m_dctButtonStates = nil;
  
  [m_arControls release];
  m_arControls = nil;

  [super dealloc];
}

/**
 * Loops over all check box controls setting enabled status.
 *
 * @param p_enabled YES to enable, NO to disable
 * @param p_except if not nil, the object that matches this will set to the opposite of p_enabled
 * @param p_clearState if YES and p_enabled is NO, all boxes that are diabled will also
 *  have their states cleared to NSOffState.
 */
- (void)setCheckBoxesEnabled:(BOOL)p_enabled except:(NSButton*)p_except clearState:(BOOL)p_clearState {
  int count = [m_arControls count];
  int i;
  for(i=0; i<count; i++) {
    NSButton *btn = (NSButton*)[m_arControls objectAtIndex:i];
    
    if(btn != p_except) {
      [btn setEnabled:p_enabled];
      if(!p_enabled && p_clearState) {
        [btn setState:NSOffState];
      }
    } else {
      [btn setEnabled:!p_enabled];
    }
  }
}

/**
 * Check if process is running and confirm before exiting.
 */
- (NSApplicationTerminateReply)applicationShouldTerminate:(NSApplication *)sender {
  if([m_processTask isRunning]) {
    [self stopProcess:self];
    return NSTerminateLater;
  } else {
    return NSTerminateNow;
  }
}

/**
 * Close the app when the window closes.
 */
- (void)windowWillClose:(NSNotification *)notification {
  if([notification object] == [self window]) {
    [NSApp terminate:self];
  }
}

/**
 * Check that a string is a valid IMEI - 15-16 digits.
 */
- (BOOL)checkImei:(NSString*)p_imei {
  if([p_imei length] != 15 && [p_imei length] != 16) {
    return NO;
  } else {
    const char *ch = [p_imei cString];
    int i;
    for(i=0; i<strlen(ch); i++) {
      if(!is_digit(ch[i])) {
         return NO;
      }
    }
  }
  
  return YES;
}

/**
 * Writes progress to the screen.
 */
- (void)writeProgress:(NSString*)p_str messageType:(int)p_msgType {
  NSDictionary *attributes = nil;
  switch(p_msgType) {
    case PMT_NORMAL:
      attributes = [NSDictionary dictionaryWithObjectsAndKeys:@"", @"NORMALTEXT", nil];
      break;
    case PMT_ERROR:
      attributes = [NSDictionary dictionaryWithObjectsAndKeys:[NSColor redColor], NSForegroundColorAttributeName, nil];
      break;
    case PMT_SUCCESS:
      attributes = [NSDictionary dictionaryWithObjectsAndKeys:[NSColor blueColor], NSForegroundColorAttributeName, nil];
      break;
  }
  
  NSAttributedString *attText = [[NSAttributedString alloc] initWithString:p_str attributes:attributes];
  NSTextStorage *ts = [m_txtProgress textStorage];
  [ts appendAttributedString:attText];
  [attText release];
  [m_txtProgress scrollRangeToVisible:NSMakeRange([ts length], 0)];
}

/**
 * Validate parameters, then start the unlocking process.
 */
- (IBAction)startProcess:(id)sender {
  if([m_btnChangeImei state] == NSOnState) {
    [m_txtImei validateEditing];
  }
  
  // Figure out the options:
  NSMutableArray *opts = [NSMutableArray arrayWithCapacity:15];
  
  // First get the singleton's taken care of
  if([m_btnDowngrade state]) {
    [opts addObject:@"-b"];
  } else {
    // Activate?
    if([m_btnActivate state]) {
      [opts addObject:@"-a"];
    }
    
    // Jailbreak?
    if([m_btnJailbreak state]) {
      [opts addObject:@"-j"];
    }
    
    if([m_btnUnlock state]) {
      [opts addObject:@"-u"];
      
      if([m_btnChangeImei state]) {
        NSString *strImei = [m_txtImei stringValue];
        if(![self checkImei:strImei]) {
          NSAlert *lert = [NSAlert alertWithMessageText:@"Invalid IMEI" 
                                          defaultButton:@"OK" 
                                        alternateButton:nil 
                                            otherButton:nil 
                              informativeTextWithFormat:@"The new IMEI number must be 15 or 16 digits"];
          [lert runModal];
          return;
        }
        [opts addObject:@"-i"];
        [opts addObject:strImei];
      }
    } else {
      if([m_btnErase state]) {
        [opts addObject:@"-e"];
      }
    }
  }
  
  if([opts count] == 0) {
    NSAlert *lert = [NSAlert alertWithMessageText:@"No parameters selected" 
                                    defaultButton:@"OK" 
                                  alternateButton:nil 
                                      otherButton:nil 
                        informativeTextWithFormat:@"You must pick at least one action parameter from the checkboxes on the left."];
    [lert runModal];
    return;
  }
  
  // Run the command
  [self startConsoleWithOptions:opts];
}

/**
 * Start the command line process with an array of command line parameters.
 */
- (void)startConsoleWithOptions:(NSArray*)opts {
  // Prevent any changes while we run.
  [self setCheckBoxesEnabled:NO except:nil clearState:NO];
  
  // Toggle buttons
  [m_btnStart setEnabled:NO];
  [m_btnStop setEnabled:YES];
  [m_tableView setEnabled:NO];

  //NSLog(@"Running ziphone with options: %@", opts);
  
  NSString *toolPath = [[NSBundle mainBundle] pathForResource:@"ziphone" ofType:@""];
  
  // The ziphone binary could easily be lacking its X bit.
  [NSTask launchedTaskWithLaunchPath:@"/bin/chmod" arguments:[NSArray arrayWithObjects:@"+x", toolPath, nil]];  
  
  NSNotificationCenter *defaultCenter = [NSNotificationCenter defaultCenter];
    
  NSDictionary *defaultEnvironment = [[NSProcessInfo processInfo] environment];
  NSMutableDictionary *environment = [[NSMutableDictionary alloc] initWithDictionary:defaultEnvironment];
  m_processTask = [[NSTask alloc] init];
  [defaultCenter addObserver:self selector:@selector(taskCompleted:) name:NSTaskDidTerminateNotification object:m_processTask];
  [m_processTask setLaunchPath:toolPath];
  [m_processTask setArguments:opts];
  [m_processTask setCurrentDirectoryPath:[[NSBundle mainBundle] resourcePath]];
  [environment setObject:@"YES" forKey:@"NSUnbufferedIO"];
  //[m_processTask setEnvironment:environment];
  NSPipe *outputPipe = [NSPipe pipe];
  NSFileHandle *taskOutput = [outputPipe fileHandleForReading];
  [defaultCenter addObserver:self selector:@selector(taskDataAvailable:) name:NSFileHandleReadCompletionNotification object:taskOutput];
  [m_processTask setStandardOutput:outputPipe];
  [m_processTask setStandardError:outputPipe];
  
//  NSPipe *inputPipe = [NSPipe pipe];
//  NSFileHandle *taskInput = [inputPipe fileHandleForWriting];
//  [m_processTask setStandardInput:inputPipe];

  [m_processTask launch];
  [taskOutput readInBackgroundAndNotify];
  
  [environment release];
}

/**
 * Callback when task is completed.
 */
- (void)taskCompleted:(NSNotification *)notif {
  NSTask *theTask = [notif object];
  int exitCode = [theTask terminationStatus];
 
  if(exitCode != 0) {
    [self writeProgress:[NSString stringWithFormat:@"\n\nERROR: ziphone returned %d", exitCode] messageType:PMT_ERROR];
  } else {
    [self writeProgress:@"\n\nZiPhone completed successfully!" messageType:PMT_SUCCESS];
  }
  
  [[NSNotificationCenter defaultCenter] removeObserver:self];

  // Call this to clean up the GUI.
  [self stopProcess:self];
}

/**
 * Take data from the running task and display it to the screen.
 */
- (void)taskDataAvailable:(NSNotification *)notif {
  NSData *incomingData = [[notif userInfo] objectForKey:NSFileHandleNotificationDataItem];
  if (incomingData && [incomingData length]) {
    NSString *incomingText = [[NSString alloc] initWithData:incomingData encoding:NSASCIIStringEncoding];
    [self writeProgress:incomingText messageType:PMT_NORMAL];
    
    [[notif object] readInBackgroundAndNotify];
    [incomingText release];
  }
}

/**
 * Warn the user, then kill -9 ziphone.
 */
- (IBAction)stopProcess:(id)sender {
  if([m_processTask isRunning]) {
    NSAlert *lert = [NSAlert alertWithMessageText:@"Are you sure you want to kill ZiPhone?" 
                                    defaultButton:@"Keep Running" 
                                  alternateButton:@"Kill It"
                                      otherButton:nil 
                        informativeTextWithFormat:@"Killing ZiPhone now may cause damage to your phone and/or baseband!"];
    [lert setAlertStyle:NSCriticalAlertStyle];
    
    [lert beginSheetModalForWindow:[self window] modalDelegate:self didEndSelector:@selector(killAlertDidEnd:returnCode:contextInfo:) contextInfo:nil];
  } else {
    // It's not really running, so just cut to the chase...
    [self killAlertDidEnd:nil returnCode:NSAlertAlternateReturn contextInfo:NULL];
  }
}

/**
 * Handle the user's confirmation selection on kill.
 */
- (void)killAlertDidEnd:(NSAlert*) p_lert returnCode:(int) p_ret contextInfo:(void*)p_ctx {
  [[p_lert window] orderOut:self];
  
  if(p_ret == NSAlertAlternateReturn) {
    // She chose down....
        
    // Kill the task:
    if([m_processTask isRunning]) {
      [m_processTask terminate];
      [m_processTask dealloc];
      m_processTask = nil;
      [self writeProgress:@"\nZiPhone killed!" messageType:PMT_ERROR];
    }
    
    // Toggle buttons
    [m_btnStart setEnabled:YES];
    [m_btnStop setEnabled:NO];
    
    // Fix the checkboxes
    [self setCheckBoxesEnabled:YES except:nil clearState:NO];
    [self checkboxClicked:self];
    
    [m_tableView setEnabled:YES];     
    
    // Let NSApp know it's time to go
    [NSApp replyToApplicationShouldTerminate:YES];
  } else {
    // Otherwise, keep going.
    [NSApp replyToApplicationShouldTerminate:NO];
  }
}

/**
 * Kill ZiPhone if necessary, then quit.
 */
- (IBAction)quitApplication:(id)sender {
  [NSApp terminate:self];
}

/**
 * Show the help/about box.
 */
- (IBAction)showAbout:(id)sender {
  if([m_btnChangeImei state] == NSOnState) {
    [m_txtImei validateEditing];
  }
  
  static BOOL bLoaded = NO;
  
  if(!bLoaded) {
    [self loadFile:@"README.txt" toTextView:m_txtAbout];
    [self loadFile:@"TROUBLESHOOTING.txt" toTextView:m_txtTrouble];    
    bLoaded = YES;
  }
  
  [m_wndAbout makeKeyAndOrderFront:self];
}

/**
 * Load the given text file from the resource directory and display it in
 * the given text view.
 */
- (void)loadFile:(NSString*)p_file toTextView:(NSTextView*)p_tv {
  NSString *strReadMe = [[NSBundle mainBundle] pathForResource:p_file ofType:nil];
  NSString *strReadMeContents = [NSString stringWithContentsOfFile:strReadMe];
  
  NSFont *font = [NSFont fontWithName:@"Courier" size:12.0];
  NSDictionary *att = [NSDictionary dictionaryWithObjectsAndKeys:font, NSFontAttributeName, nil];
  NSAttributedString *attText = [[NSAttributedString alloc] initWithString:strReadMeContents attributes:att];
  
  [[p_tv textStorage] appendAttributedString:attText];
  [attText release];
}

/**
 * React to checkbox changes by validating parameters.
 *
 * This method will enable/disable checkboxes according to what's
 * possible based on other selections.
 *
 * ChangeIMEI requires Unlock.
 * Unlock disables iErase since they're for different firmwares.
 */
- (IBAction)checkboxClicked:(id)sender {
  int count = [m_arControls count];
  int i;
  for(i=0; i<count; i++) {
    NSControl *btn = (NSControl*)[m_arControls objectAtIndex:i];
    
    // Grab the requirements for this object
    NSDictionary *statesDict = [m_dctButtonStates objectForKey:[NSNumber numberWithInt:[btn tag]]];
    NSArray *reqList = [statesDict objectForKey:ONLYSHOWIF_KEY];
    NSArray *dqList = [statesDict objectForKey:NOSHOWIF_KEY];
    
    // Start assuming we can show it
    BOOL bCanShow = YES;
    
    // Make sure that all pre-requisites are in place
    int j;
    int listCt = [reqList count];
    for(j=0; j<listCt; j++) {
      NSButton *req = (NSButton*)[reqList objectAtIndex:j];
      if(![req state]) {
        // We're missing a required item for this button.  Disable it.
        bCanShow = NO;
        break;        
      }
    }
    
    // If all the requirements are here, see if anything disqualifies it.
    if(bCanShow) {
      listCt = [dqList count];
      for(j=0; j<listCt; j++) {
        NSButton *dq = (NSButton*)[dqList objectAtIndex:j];
        if([dq state]) {
          // We have an item which disqualifies this button.  Disable it.
          bCanShow = NO;
          break;
        }
      }
    }
    
    [btn setEnabled:bCanShow];
    if(!bCanShow && [btn respondsToSelector:@selector(setState:)]) {
      NSButton *tmp = (NSButton*)btn;
      [tmp setState:NSOffState];
    }
  }  
  
  [m_txtImei validateEditing];
  
  // It takes two passes to get some of these right...
  if(sender != (id)2) {
    [self checkboxClicked:(id)2];
  }
}

/**
 * Run reboot-only test.
 */
-(IBAction)mnuTestSelected:(id)sender {
  [self startConsoleWithOptions:[NSArray arrayWithObjects:@"-t", nil]];
}

/**
 * Run MD5 check.
 */
- (IBAction)mnuCoffeeSelected:(id)sender {
  [self startConsoleWithOptions:[NSArray arrayWithObjects:@"-C", nil]];
}

/**
 * Open the website.
 */
- (IBAction)openWebsite:(id)sender {
  [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"http://www.ziphone.org/"]];
}

/**
 * Do everything (-Z Y).
 */
- (IBAction)aioDoItAll:(id)sender {
  [self startConsoleWithOptions:[NSArray arrayWithObjects:@"-Z", @"Y", nil]];
}

/**
 * Everything but unlock (-Z N).
 */
- (IBAction)aioDontUnlock:(id)sender {
  [self startConsoleWithOptions:[NSArray arrayWithObjects:@"-Z", @"N", nil]];
}

/**
 * JB only (-j).
 */
- (IBAction)aioJailbreak:(id)sender {
    [self startConsoleWithOptions:[NSArray arrayWithObjects:@"-j", nil]];
}

/**
 * Erase baseband (-b).
 */
- (IBAction)aioRefurbish:(id)sender {
    [self startConsoleWithOptions:[NSArray arrayWithObjects:@"-b", nil]];
}

/**
 * Restart in DFU mode.
 */
- (IBAction)dfuMode:(id)sender {
  [self startConsoleWithOptions:[NSArray arrayWithObjects:@"-D", nil]];
}

/** 
 * Restart in recovery mode.
 */
- (IBAction)recoveryMode:(id)sender {
  [self startConsoleWithOptions:[NSArray arrayWithObjects:@"-R", nil]];
}

/**
 * Normal restart (clear boot args).
 */
- (IBAction)normalMode:(id)sender {
  [self startConsoleWithOptions:[NSArray arrayWithObjects:@"-N", nil]];
}


/**
 * Return the number of items in the button table.
 */
- (int)numberOfRowsInTableView:(NSTableView *)aTableView {
  return 4;
}


/**
 * Return an object to display in the column/row.
 */
- (id)tableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)aTableColumn row:(int)rowIndex {
  if([[aTableColumn identifier] isEqualToString:@"text"]) {
    return @"";
  } else {
    switch(rowIndex) {
      case 0:
        return [NSImage imageNamed:@"Unlocked.tif"];
        break;
      case 1:
        return [NSImage imageNamed:@"Unlocked.tif"];
        break;
      case 2:
        return [NSImage imageNamed:@"Key.tif"];
        break;
      case 3:
        return [NSImage imageNamed:@"Locked.tif"];
        break;
      default:
        return nil;
    }
  }
}

/**
 * Adjust settings for individual table cells.
 */
- (void)tableView:(NSTableView *)tableView willDisplayCell:(id)cell forTableColumn:(NSTableColumn *)tableColumn row:(int)row {
  if([[tableColumn identifier] isEqualToString:@"text"]) {
    NSString *html = nil;
    
    switch(row) {
      case 0:
        html = @"<font size=\"+2\"><b>Do it all!</b></font><br/>Unlock, jailbreak, and activate";
        break;
      case 1:
        html = @"<font size=\"+2\"><b>Don't Unlock</b></font><br/>Jailbreak and activate only";
        break;
      case 2:
        html = @"<font size=\"+2\"><b>Jailbreak</b></font><br/>Best choice for 'official' carriers.<br/>Some 8GB iPod's also supported";
        break;
      case 3:
        html = @"<font size=\"+2\"><b>Refurbish</b></font><br/>Erase baseband - restore will replace locks";
        break;
    }  
    
    NSURL *baseURL = [NSURL fileURLWithPath:[[NSBundle mainBundle] resourcePath]];
    NSData *htmlData = [html dataUsingEncoding:NSUTF8StringEncoding];
    NSAttributedString *attStr = [[NSAttributedString alloc] initWithHTML:htmlData baseURL:baseURL documentAttributes:nil];
    
    [cell setAttributedStringValue:attStr];
    
    [attStr release];
  }
}

/**
 * Delegate method detects when table item is clicked.
 */
- (void)tableViewSelectionDidChange:(NSNotification *)note {
  NSTableView *tableView = [note object];
  switch([tableView selectedRow]) {
    case 0:
      [self aioDoItAll:self];
      break;
    case 1:
      [self aioDontUnlock:self];
      break;
    case 2:
      [self aioJailbreak:self];
      break;
    case 3:
      [self aioRefurbish:self];
      break;
  }
}

/**
 * Don't allow selection to change if process is running.
 */
- (BOOL)selectionShouldChangeInTableView:(NSTableView *)aTableView {
  if([m_processTask isRunning]) {
    return NO;
  } else {
    return YES;
  }
}
@end

