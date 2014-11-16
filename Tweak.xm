#import <Accelerate/Accelerate.h>
#import <SpringBoard/SBApplication.h>
#import <SpringBoard/SBApplicationIcon.h>
#import <UIKit/UIImage+Private.h>

NSCache *cache;

struct pixel {
	unsigned char r, g, b, a;
};

static NSUInteger BytesPerPixel = 4;
static NSUInteger BitsPerComponent = 8;

#pragma mark - Resize image

// http://stackoverflow.com/a/10099016/709376

UIImage *HBPTResizeImage(UIImage *oldImage, CGSize newSize) {
	if (!oldImage) {
		return nil;
	}

	UIImage *newImage = nil;

	CGImageRef cgImage = oldImage.CGImage;
	NSUInteger oldWidth = CGImageGetWidth(cgImage);
	NSUInteger oldHeight = CGImageGetHeight(cgImage);
	CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();

	pixel *oldData = (pixel *)calloc(oldHeight * oldWidth * BytesPerPixel, sizeof(pixel));
	NSUInteger oldBytesPerRow = BytesPerPixel * oldWidth;

	CGContextRef context = CGBitmapContextCreate(oldData, oldWidth, oldHeight, BitsPerComponent, oldBytesPerRow, colorSpace, kCGImageAlphaPremultipliedFirst | kCGBitmapByteOrder32Big);
	CGContextDrawImage(context, CGRectMake(0, 0, oldWidth, oldHeight), cgImage);
	CGContextRelease(context);

	NSUInteger newWidth = (NSUInteger)newSize.width, newHeight = (NSUInteger)newSize.height, newBytesPerRow = BytesPerPixel * newWidth;
	pixel *newData = (pixel *)calloc(newHeight * newWidth * BytesPerPixel, sizeof(pixel));

	vImage_Buffer oldBuffer = {
		.data = oldData,
		.height = oldHeight,
		.width = oldWidth,
		.rowBytes = oldBytesPerRow
	};

	vImage_Buffer newBuffer = {
		.data = newData,
		.height = newHeight,
		.width = newWidth,
		.rowBytes = newBytesPerRow
	};

	vImage_Error error = vImageScale_ARGB8888(&oldBuffer, &newBuffer, NULL, kvImageHighQualityResampling);

	free(oldData);

	CGContextRef newContext = CGBitmapContextCreate(newData, newWidth, newHeight, BitsPerComponent, newBytesPerRow, colorSpace, kCGImageAlphaPremultipliedFirst | kCGBitmapByteOrder32Big);
	CGImageRef cgImageNew = CGBitmapContextCreateImage(newContext);

	newImage = [UIImage imageWithCGImage:cgImageNew];

	CGImageRelease(cgImageNew);
	CGColorSpaceRelease(colorSpace);
	CGContextRelease(newContext);

	free(newData);

	if (error != kvImageNoError) {
		NSLog(@"PreThree: failed to scale image: error %ld", error);
		return oldImage;
	}

	return newImage;
}

#pragma mark - Hook

%hook SBApplicationIcon

- (UIImage *)generateIconImage:(SBApplicationIconFormat)format {
	UIImage *oldImage = %orig;

	if (oldImage.scale >= [UIScreen mainScreen].scale) {
		return oldImage;
	}

	if (format != SBApplicationIconFormatDefault && format != SBApplicationIconFormatSpotlight && format != SBApplicationIconFormatTiny) {
		return oldImage;
	}

	NSString *key = [NSString stringWithFormat:@"%@_format:%lu", self.application.bundleIdentifier, (unsigned long)format];

	if ([cache objectForKey:key]) {
		return [cache objectForKey:key];
	}

	UIImage *iTunesArtwork = [UIImage imageWithContentsOfFile:[self.application.bundleContainerPath stringByAppendingPathComponent:@"iTunesArtwork"]];

	if (!iTunesArtwork) {
		NSLog(@"PreThree: failed to get iTunesArtwork for %@", self.application.bundleIdentifier);
		return oldImage;
	}

	CGFloat newSize = oldImage.size.width * [UIScreen mainScreen].scale;
	UIImage *image = [HBPTResizeImage(iTunesArtwork, CGSizeMake(newSize, newSize)) _applicationIconImageForFormat:format precomposed:YES scale:[UIScreen mainScreen].scale];

	[cache setObject:image forKey:key];

	return image;
}

%end

%ctor {
	cache = [[NSCache alloc] init];

	if ([UIScreen mainScreen].scale < 3.f) {
		NSLog(@"PreThree: huh, running on a %f screen?", [UIScreen mainScreen].scale);
	}

	%init;
}
