//
//  HPTextView.m
//
//  Created by Hans Pinckaers on 29-06-10.
//
//	MIT License
//
//	Copyright (c) 2011 Hans Pinckaers
//
//	Permission is hereby granted, free of charge, to any person obtaining a copy
//	of this software and associated documentation files (the "Software"), to deal
//	in the Software without restriction, including without limitation the rights
//	to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//	copies of the Software, and to permit persons to whom the Software is
//	furnished to do so, subject to the following conditions:
//
//	The above copyright notice and this permission notice shall be included in
//	all copies or substantial portions of the Software.
//
//	THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//	IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//	FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//	AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//	LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//	OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//	THE SOFTWARE.

#import "HPGrowingTextView.h"
#import "HPTextViewInternal.h"

@interface HPGrowingTextView(private)
-(void)commonInitialiser;
-(void)resizeTextView:(NSInteger)newSizeH;
-(void)growDidStop;
@end

@implementation HPGrowingTextView
@synthesize internalTextView;
@synthesize delegate;

@synthesize font;
@synthesize textColor;
@synthesize textAlignment; 
@synthesize selectedRange;
@synthesize editable;
@synthesize dataDetectorTypes; 
@synthesize animateHeightChange;
@synthesize returnKeyType;
@dynamic placeholder;
@dynamic placeholderColor;

// having initwithcoder allows us to use HPGrowingTextView in a Nib. -- aob, 9/2011
- (id)initWithCoder:(NSCoder *)aDecoder
{
    if ((self = [super initWithCoder:aDecoder])) {
        [self commonInitialiser];
    }
    return self;
}

- (id)initWithFrame:(CGRect)frame {
    if ((self = [super initWithFrame:frame])) {
        [self commonInitialiser];
    }
    return self;
}

-(BOOL) isUpperSDK
{
    if (floor(NSFoundationVersionNumber) > NSFoundationVersionNumber_iOS_6_1) {
        return YES;
    }
    return NO;
}

-(void)commonInitialiser
{
    // Initialization code
    CGRect r = self.frame;
    r.origin.y = 0;
    r.origin.x = 0;
    internalTextView = [[HPTextViewInternal alloc] initWithFrame:r];
//    internalTextView = [[UITextView alloc] initWithFrame:r];
    internalTextView.delegate = self;
    if (![self isUpperSDK]) {
        internalTextView.scrollEnabled = NO;
    }
    internalTextView.font = [UIFont fontWithName:@"Helvetica" size:13];
    internalTextView.contentInset = UIEdgeInsetsZero;
    internalTextView.showsHorizontalScrollIndicator = NO;
    internalTextView.text = @"-";
    internalTextView.scrollsToTop = NO;
    [self addSubview:internalTextView];
    
    //默认的contentInset
    minHeight = internalTextView.frame.size.height;
    minNumberOfLines = 1;
    animateHeightChange = YES;
    
    internalTextView.text = @"";
//    [self setMaxNumberOfLines:3];
    
    [self setPlaceholderColor:[UIColor lightGrayColor]];
    internalTextView.displayPlaceHolder = YES;

    
    maxNumberOfLines = 3;
}

- (NSString *)placeholder
{
    return internalTextView.placeholder;
}

- (void)setPlaceholder:(NSString *)placeholder
{
    [internalTextView setPlaceholder:placeholder];
    [internalTextView setNeedsDisplay];
}

- (UIColor *)placeholderColor
{
    return internalTextView.placeholderColor;
}

- (void)setPlaceholderColor:(UIColor *)placeholderColor
{
    [internalTextView setPlaceholderColor:placeholderColor];
}

-(void)setBlockMenuAction:(BOOL)blockMenuAction{
    _blockMenuAction = blockMenuAction;
    [internalTextView setBlockMenuAction:blockMenuAction];
}

-(CGSize)sizeThatFits:(CGSize)size
{
    if (self.text.length == 0) {
        size.height = minHeight;
    }
    return size;
}

-(void)layoutSubviews
{
    [super layoutSubviews];
    
    BOOL isWidthChanged = NO;
    
	CGRect r = [self resizeTextViewWithContentInset];

    //判断宽度是否变化
    if (fabsf(internalTextView.frame.size.width - r.size.width) > 0.000001) {
        isWidthChanged = YES;
    }
    
    internalTextView.frame = r;
    
    if (isWidthChanged) {
        [self textViewDidChange:internalTextView];
    }
}

-(void)setContentInset:(UIEdgeInsets)inset
{
    contentInset = inset;
    
    [self resizeTextViewWithContentInset];
    
    [self setMaxNumberOfLines:maxNumberOfLines];
    [self setMinNumberOfLines:minNumberOfLines];
}

-(UIEdgeInsets)contentInset
{
    return contentInset;
}

-(CGFloat) calculateTextViewHeight:(UITextView *) textView
{
    //ios7 就重新计算
    if ([NSString instancesRespondToSelector:@selector(boundingRectWithSize:options:attributes:context:)]) {
        CGRect txtFrame = textView.frame;
        //@"%@\n "
        return [[NSString stringWithFormat:@"%@\n ",textView.text]                boundingRectWithSize:CGSizeMake(txtFrame.size.width - textView.contentInset.left - textView.contentInset.right, CGFLOAT_MAX)
                                                                                               options:NSStringDrawingUsesLineFragmentOrigin | NSStringDrawingUsesFontLeading
                                                                                            attributes:[NSDictionary dictionaryWithObjectsAndKeys:textView.font,NSFontAttributeName, nil] context:nil].size.height;
    }
    
    //ios6 及以前可以直接返回textview的contentSize
    return textView.contentSize.height ;//- textView.contentInset.top - textView.contentInset.bottom;
}

-(void)setMaxNumberOfLines:(int)n
{
    // Use internalTextView for height calculations, thanks to Gwynne <http://blog.darkrainfall.org/>
    NSString *saveText = internalTextView.text, *newText = @"-";
    
    internalTextView.delegate = nil;
    internalTextView.hidden = YES;
    
    for (int i = 1; i < n; ++i)
        newText = [newText stringByAppendingString:@"\n|W|"];
    
    internalTextView.text = newText;
    
//    maxHeight = internalTextView.contentSize.height;
    //ios7
//    UIEdgeInsets inset = internalTextView.textContainerInset;
//    maxHeight = [LSUIUtils reSizeTextViewContentSize:internalTextView].height + inset.bottom;

    maxHeight = [self calculateTextViewHeight:internalTextView];
    
    internalTextView.text = saveText;
    internalTextView.hidden = NO;
    internalTextView.delegate = self;
    
    [self sizeToFit];
    
    maxNumberOfLines = n;
}

-(int)maxNumberOfLines
{
    return maxNumberOfLines;
}


//因上面方法在计算时处于换行临界情况下时会出现误差，所以取两次计算结果大的一方
-(CGSize) reSizeTextViewContentSize:(UITextView *) textview
{
    if ([textview respondsToSelector:@selector(textContainerInset)]) {
        //防止光标在中间时会有问题，先把原即是位置记录下来，把光标移动到最后
        NSRange oringalRange = textview.selectedRange;
        textview.selectedRange = NSMakeRange(textview.text.length, 0);
        CGRect line = [textview caretRectForPosition:
                       textview.selectedTextRange.start];
        
        UIEdgeInsets inset = textview.textContainerInset;
        CGSize newSize = CGSizeMake(ceil(line.size.width)  + inset.left + inset.right,
                                    ceil(line.size.height + line.origin.y) + inset.top);
        
        textview.contentSize = newSize;
        
        //还原原始光标
        textview.selectedRange = oringalRange;
    }
    
    return textview.contentSize;
}

-(void)setMinNumberOfLines:(int)m
{
	// Use internalTextView for height calculations, thanks to Gwynne <http://blog.darkrainfall.org/>
    NSString *saveText = internalTextView.text, *newText = @"-";
    
    internalTextView.delegate = nil;
    internalTextView.hidden = YES;
    
    for (int i = 1; i < m; ++i)
        newText = [newText stringByAppendingString:@"\n|W|"];
    
    internalTextView.text = newText;
    
//    minHeight = internalTextView.contentSize.height;
    minHeight = [self reSizeTextViewContentSize:internalTextView].height;
    
    internalTextView.text = saveText;
    internalTextView.hidden = NO;
    internalTextView.delegate = self;
    
    [self sizeToFit];
    
    minNumberOfLines = m;
}

-(int)minNumberOfLines
{
    return minNumberOfLines;
}

-(BOOL)canPerformAction:(SEL)action withSender:(id)sender{
    if (self.blockMenuAction) {
        return NO;
    }
    return [super canPerformAction:action withSender:sender];
}

- (void)textViewDidChange:(UITextView *)textView
{
	//size of content, so we can set the frame of self
    
//	NSInteger newSizeH = internalTextView.contentSize.height;
    NSInteger newSizeH = [self reSizeTextViewContentSize:textView].height;
	if(newSizeH < minHeight || !internalTextView.hasText) newSizeH = minHeight; //not smalles than minHeight
    if (internalTextView.frame.size.height > maxHeight) newSizeH = maxHeight; // not taller than maxHeight

	if (internalTextView.frame.size.height != newSizeH)
	{
        // [fixed] Pasting too much text into the view failed to fire the height change, 
        // thanks to Gwynne <http://blog.darkrainfall.org/>
        
        if (newSizeH > maxHeight && internalTextView.frame.size.height <= maxHeight)
        {
            newSizeH = maxHeight;
        }
        
		if (newSizeH <= maxHeight)
		{
            if(animateHeightChange) {
                
                if ([UIView resolveClassMethod:@selector(animateWithDuration:animations:)]) {
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 40000
                    [UIView animateWithDuration:0.1f 
                                          delay:0 
                                        options:(UIViewAnimationOptionAllowUserInteraction|
                                                 UIViewAnimationOptionBeginFromCurrentState)                                 
                                     animations:^(void) {
                                         [self resizeTextView:newSizeH];
                                     } 
                                     completion:^(BOOL finished) {
                                         if ([delegate respondsToSelector:@selector(growingTextView:didChangeHeight:)]) {
                                             [delegate growingTextView:self didChangeHeight:newSizeH];
                                         }
                                     }];
#endif
                } else {
                    [UIView beginAnimations:@"" context:nil];
                    [UIView setAnimationDuration:0.1f];
                    [UIView setAnimationDelegate:self];
                    [UIView setAnimationDidStopSelector:@selector(growDidStop)];
                    [UIView setAnimationBeginsFromCurrentState:YES];
                    [self resizeTextView:newSizeH];
                    [UIView commitAnimations];
                }
            } else {
                [self resizeTextView:newSizeH];                
                // [fixed] The growingTextView:didChangeHeight: delegate method was not called at all when not animating height changes.
                // thanks to Gwynne <http://blog.darkrainfall.org/>
                
                if ([delegate respondsToSelector:@selector(growingTextView:didChangeHeight:)]) {
                    [delegate growingTextView:self didChangeHeight:newSizeH];
                }	
            }
		}
		
        
        // if our new height is greater than the maxHeight
        // sets not set the height or move things
        // around and enable scrolling
        
        if (![self isUpperSDK]) {
            if (newSizeH >= maxHeight)
            {
                if(!internalTextView.scrollEnabled){
                    internalTextView.scrollEnabled = YES;
                    [internalTextView flashScrollIndicators];
                }
            } else {
                internalTextView.scrollEnabled = NO;
            }
        }
	}
	
    
    // Display (or not) the placeholder string
    
    BOOL wasDisplayingPlaceholder = internalTextView.displayPlaceHolder;
    internalTextView.displayPlaceHolder = self.internalTextView.text.length == 0;
    
    if (wasDisplayingPlaceholder != internalTextView.displayPlaceHolder) {
        [internalTextView setNeedsDisplay];
    }

	
	if ([delegate respondsToSelector:@selector(growingTextViewDidChange:)]) {
		[delegate growingTextViewDidChange:self];
	}
}

-(void)resizeTextView:(NSInteger)newSizeH
{
    if ([delegate respondsToSelector:@selector(growingTextView:willChangeHeight:)]) {
        [delegate growingTextView:self willChangeHeight:newSizeH];
    }
    
    CGRect internalTextViewFrame = self.frame;
    internalTextViewFrame.size.height = newSizeH; // + padding
    self.frame = internalTextViewFrame;
    
    [self resizeTextViewWithContentInset];
    //?????20131209为什么会在resizeTextviewframe再去改变textview的大小，并且设置了跟parent一样大？
//    internalTextView.frame = internalTextViewFrame;
}

-(CGRect) resizeTextViewWithContentInset
{
    CGRect internalTextViewFrame = self.frame;
    internalTextViewFrame.origin.y = contentInset.top;
    internalTextViewFrame.origin.x = contentInset.left;
    internalTextViewFrame.size.width -= contentInset.left + contentInset.right;
    internalTextViewFrame.size.height -= contentInset.top + contentInset.bottom;
    
    internalTextView.frame = internalTextViewFrame;
//    [internalTextView setScrollIndicatorInsets:UIEdgeInsetsMake(2, 0, 0, 0)];
    [internalTextView setContentInset:UIEdgeInsetsMake(-(contentInset.top / 2), 0, 0, 0)];
    return internalTextViewFrame;
}

-(void)growDidStop
{
	if ([delegate respondsToSelector:@selector(growingTextView:didChangeHeight:)]) {
		[delegate growingTextView:self didChangeHeight:self.frame.size.height];
	}
	
}

-(void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
    [internalTextView becomeFirstResponder];
}

- (BOOL)becomeFirstResponder
{
    [super becomeFirstResponder];
    return [self.internalTextView becomeFirstResponder];
}

-(BOOL)resignFirstResponder
{
	[super resignFirstResponder];
	return [internalTextView resignFirstResponder];
}

-(BOOL)isFirstResponder
{
  return [self.internalTextView isFirstResponder];
}


///////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark UITextView properties
///////////////////////////////////////////////////////////////////////////////////////////////////

-(void)setText:(NSString *)newText
{
    
    internalTextView.text = newText;

    // include this line to analyze the height of the textview.
    // fix from Ankit Thakur
    [self performSelector:@selector(textViewDidChange:) withObject:internalTextView];
}

-(NSString*) text
{
    return internalTextView.text;
}

///////////////////////////////////////////////////////////////////////////////////////////////////

-(void)setFont:(UIFont *)afont
{
	internalTextView.font = afont;
	
	[self setMaxNumberOfLines:maxNumberOfLines];
	[self setMinNumberOfLines:minNumberOfLines];
}

-(UIFont *)font
{
	return internalTextView.font;
}	

///////////////////////////////////////////////////////////////////////////////////////////////////

-(void)setTextColor:(UIColor *)color
{
	internalTextView.textColor = color;
}

-(UIColor*)textColor{
	return internalTextView.textColor;
}

///////////////////////////////////////////////////////////////////////////////////////////////////

-(void)setBackgroundColor:(UIColor *)backgroundColor
{
  [super setBackgroundColor:backgroundColor];
	internalTextView.backgroundColor = backgroundColor;
}

-(UIColor*)backgroundColor
{
  return internalTextView.backgroundColor;
}

///////////////////////////////////////////////////////////////////////////////////////////////////

-(void)setTextAlignment:(UITextAlignment)aligment
{
	internalTextView.textAlignment = aligment;
}

-(UITextAlignment)textAlignment
{
	return internalTextView.textAlignment;
}

///////////////////////////////////////////////////////////////////////////////////////////////////

-(void)setSelectedRange:(NSRange)range
{
	internalTextView.selectedRange = range;
}

-(NSRange)selectedRange
{
	return internalTextView.selectedRange;
}

///////////////////////////////////////////////////////////////////////////////////////////////////

-(void)setEditable:(BOOL)beditable
{
	internalTextView.editable = beditable;
}

-(BOOL)isEditable
{
	return internalTextView.editable;
}

///////////////////////////////////////////////////////////////////////////////////////////////////

-(void)setReturnKeyType:(UIReturnKeyType)keyType
{
	internalTextView.returnKeyType = keyType;
}

-(UIReturnKeyType)returnKeyType
{
	return internalTextView.returnKeyType;
}

///////////////////////////////////////////////////////////////////////////////////////////////////

- (void)setEnablesReturnKeyAutomatically:(BOOL)enablesReturnKeyAutomatically
{
  internalTextView.enablesReturnKeyAutomatically = enablesReturnKeyAutomatically;
}

- (BOOL)enablesReturnKeyAutomatically
{
  return internalTextView.enablesReturnKeyAutomatically;
}

///////////////////////////////////////////////////////////////////////////////////////////////////

-(void)setDataDetectorTypes:(UIDataDetectorTypes)datadetector
{
	internalTextView.dataDetectorTypes = datadetector;
}

-(UIDataDetectorTypes)dataDetectorTypes
{
	return internalTextView.dataDetectorTypes;
}

///////////////////////////////////////////////////////////////////////////////////////////////////

- (BOOL)hasText{
	return [internalTextView hasText];
}

- (void)scrollRangeToVisible:(NSRange)range
{
	[internalTextView scrollRangeToVisible:range];
//    NSLog(@"range= %d, textview.contentSize.height = %f, textview.contentSize.width = %f, frame.size.height = %f, parent.frame.size.height = %f, contentOffset.y = %f", range.location, internalTextView.contentSize.height, internalTextView.contentSize.width, internalTextView.frame.size.height, self.frame.size.height, internalTextView.contentOffset.y);
}

/////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark UITextViewDelegate


///////////////////////////////////////////////////////////////////////////////////////////////////
- (BOOL)textViewShouldBeginEditing:(UITextView *)textView {
	if ([delegate respondsToSelector:@selector(growingTextViewShouldBeginEditing:)]) {
		return [delegate growingTextViewShouldBeginEditing:self];
		
	} else {
		return YES;
	}
}


///////////////////////////////////////////////////////////////////////////////////////////////////
- (BOOL)textViewShouldEndEditing:(UITextView *)textView {
	if ([delegate respondsToSelector:@selector(growingTextViewShouldEndEditing:)]) {
		return [delegate growingTextViewShouldEndEditing:self];
		
	} else {
		return YES;
	}
}


///////////////////////////////////////////////////////////////////////////////////////////////////
- (void)textViewDidBeginEditing:(UITextView *)textView {
    [textView scrollRangeToVisible:textView.selectedRange];
	if ([delegate respondsToSelector:@selector(growingTextViewDidBeginEditing:)]) {
		[delegate growingTextViewDidBeginEditing:self];
	}
}


///////////////////////////////////////////////////////////////////////////////////////////////////
- (void)textViewDidEndEditing:(UITextView *)textView {		
	if ([delegate respondsToSelector:@selector(growingTextViewDidEndEditing:)]) {
		[delegate growingTextViewDidEndEditing:self];
	}
}


///////////////////////////////////////////////////////////////////////////////////////////////////
- (BOOL)textView:(UITextView *)textView shouldChangeTextInRange:(NSRange)range
 replacementText:(NSString *)atext {
	
	//weird 1 pixel bug when clicking backspace when textView is empty
//	if(![textView hasText] && [atext isEqualToString:@""]) return NO;
	
	//Added by bretdabaker: sometimes we want to handle this ourselves
    if (range.location + range.length > textView.text.length && 0 == atext.length) {
        return NO;
    }
    
    if ([delegate respondsToSelector:@selector(growingTextView:shouldChangeTextInRange:replacementText:)])
        	return [delegate growingTextView:self shouldChangeTextInRange:range replacementText:atext];
	
	if ([atext isEqualToString:@"\n"]) {
		if ([delegate respondsToSelector:@selector(growingTextViewShouldReturn:)]) {
			if (![delegate performSelector:@selector(growingTextViewShouldReturn:) withObject:self]) {
				return NO;
			} else {
				[textView resignFirstResponder];
				return NO;
			}
		}
	}
	
	return YES;
	
    
}

///////////////////////////////////////////////////////////////////////////////////////////////////
- (void)textViewDidChangeSelection:(UITextView *)textView {
	if ([delegate respondsToSelector:@selector(growingTextViewDidChangeSelection:)]) {
		[delegate growingTextViewDidChangeSelection:self];
	}
}

////////////
//
-(CGFloat) getMaxHeight
{
    return maxHeight;
}

@end
