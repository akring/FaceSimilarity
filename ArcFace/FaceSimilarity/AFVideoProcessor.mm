//
//  AFVideoProcessor.mm
//  ArcFace
//
//  Created by yalichen on 2017/8/1.
//  Copyright © 2017年 ArcSoft. All rights reserved.
//

#import "AFVideoProcessor.h"
#import "ammem.h"
#import "merror.h"
#import "arcsoft_fsdk_face_tracking.h"
#import "arcsoft_fsdk_face_recognition.h"
#import "arcsoft_fsdk_face_detection.h"
#import "Utility.h"
#import "AFRManager.h"

#define AFR_DEMO_APP_ID         "3E1raq9cDzqUibpZmqNhomtupeM3Du44kVEwSuEB1Hjw"
#define AFR_DEMO_SDK_FR_KEY     "6G2TXTkxk2ZntaxsfxGE8HRGnCScq4dfmYD6rvM1Egs7"
#define AFR_DEMO_SDK_FT_KEY     "6G2TXTkxk2ZntaxsfxGE8HQeyC8n3ioNW8xJxpkXockk"
#define AFR_DEMO_SDK_FD_KEY     "6G2TXTkxk2ZntaxsfxGE8HQn8bPw5qTKCxnGossos4Zm"

#define AFR_FR_MEM_SIZE         1024*1024*40
#define AFR_FT_MEM_SIZE         1024*1024*40
#define AFR_FD_MEM_SIZE         1024*1024*40

#define AFR_FD_MAX_FACE_NUM     2

@implementation AFVideoFaceRect
@end

@interface AFVideoProcessor()
{
    MHandle          _arcsoftFD;
    MVoid*           _memBufferFD;
    
    MHandle          _arcsoftFT;
    MVoid*           _memBufferFT;
    
    MHandle          _arcsoftFR;
    MVoid*           _memBufferFR;
    
    ASVLOFFSCREEN*   _offscreenForProcess;
    dispatch_semaphore_t _processSemaphore;
}

@property (nonatomic, assign) BOOL              frModelVersionChecked;
@property (nonatomic, strong) AFRManager*       frManager;
@property (atomic, strong) AFRPerson*           frPerson;
@end

@implementation AFVideoProcessor

- (void)initProcessor
{
    // FT
    _memBufferFT = MMemAlloc(MNull,AFR_FT_MEM_SIZE);
    AFT_FSDK_InitialFaceEngine((MPChar)AFR_DEMO_APP_ID, (MPChar)AFR_DEMO_SDK_FT_KEY, (MByte*)_memBufferFT, AFR_FT_MEM_SIZE, &_arcsoftFT, AFT_FSDK_OPF_0_HIGHER_EXT, 16, AFR_FD_MAX_FACE_NUM);
    
    // FD
    _memBufferFD = MMemAlloc(MNull, AFR_FD_MEM_SIZE);
    MMemSet(_memBufferFD, 0, AFR_FD_MEM_SIZE);
    AFD_FSDK_InitialFaceEngine((MPChar)AFR_DEMO_APP_ID, (MPChar)AFR_DEMO_SDK_FD_KEY, (MByte*)_memBufferFD, AFR_FD_MEM_SIZE, &_arcsoftFD, AFD_FSDK_OPF_0_HIGHER_EXT, 16, AFR_FD_MAX_FACE_NUM);
   
    // FR
    _memBufferFR = MMemAlloc(MNull,AFR_FR_MEM_SIZE);
    AFR_FSDK_InitialEngine((MPChar)AFR_DEMO_APP_ID, (MPChar)AFR_DEMO_SDK_FR_KEY, (MByte*)_memBufferFR, AFR_FR_MEM_SIZE, &_arcsoftFR);
    
    _processSemaphore = dispatch_semaphore_create(1);
    
    self.frManager = [[AFRManager alloc] init];
}

- (void)uninitProcessor
{
    AFR_FSDK_UninitialEngine(_arcsoftFR);
    _arcsoftFR = MNull;
    if(_memBufferFR != MNull)
    {
        MMemFree(MNull,_memBufferFR);
        _memBufferFR = MNull;
    }
    
    AFT_FSDK_UninitialFaceEngine(_arcsoftFT);
    _arcsoftFT = MNull;
    if(_memBufferFT != MNull)
    {
        MMemFree(MNull, _memBufferFT);
        _memBufferFT = MNull;
    }
    
    AFD_FSDK_UninitialFaceEngine(_arcsoftFD);
    _arcsoftFD = MNull;
    if(_memBufferFD != MNull)
    {
        MMemFree(MNull, _memBufferFD);
        _memBufferFD = MNull;
    }
    
    if(0 == dispatch_semaphore_wait(_processSemaphore, 0))
    {
        [Utility freeOffscreen:_offscreenForProcess];
        _offscreenForProcess = MNull;
        
        _processSemaphore = NULL;
    }
}

/**
 获取面部模型

 @param offscreen offscreen
 @param face face
 @return 面部模型
 */
- (AFR_FSDK_FACEMODEL)getFaceModel:(LPASVLOFFSCREEN)offscreen faceInput:(AFR_FSDK_FACEINPUT)face {
    
    LPASVLOFFSCREEN pOffscreenForProcess = [self copyOffscreenForProcess:offscreen];
    
    AFR_FSDK_FACEMODEL faceModel = {0};
    AFR_FSDK_ExtractFRFeature(_arcsoftFR, pOffscreenForProcess, &face, &faceModel);
    
    AFRPerson* currentPerson = [[AFRPerson alloc] init];
    currentPerson.faceFeatureData = [NSData dataWithBytes:faceModel.pbFeature length:faceModel.lFeatureSize];
    
    AFR_FSDK_FACEMODEL currentFaceModel = {0};
    currentFaceModel.pbFeature = (MByte*)[currentPerson.faceFeatureData bytes];
    currentFaceModel.lFeatureSize = (MInt32)[currentPerson.faceFeatureData length];
    
    return currentFaceModel;
}

- (NSArray*)process:(LPASVLOFFSCREEN)offscreen
{
    MInt32 nFaceNum = 0;
    MRECT* pRectFace = MNull;
    
    __block AFR_FSDK_FACEINPUT faceInput = {0};
    if (self.detectFaceUseFD)
    {
        LPAFD_FSDK_FACERES pFaceResFD = MNull;
        AFD_FSDK_StillImageFaceDetection(_arcsoftFD, offscreen, &pFaceResFD);
        if (pFaceResFD) {
            nFaceNum = pFaceResFD->nFace;
            pRectFace = pFaceResFD->rcFace;
        }
        if (nFaceNum > 0)
        {
            faceInput.rcFace = pFaceResFD->rcFace[0];
            faceInput.lOrient = pFaceResFD->lfaceOrient[0];
        }
    }
    else
    {
        LPAFT_FSDK_FACERES pFaceResFT = MNull;
        AFT_FSDK_FaceFeatureDetect(_arcsoftFT, offscreen, &pFaceResFT);
        if (pFaceResFT) {
            nFaceNum = pFaceResFT->nFace;
            pRectFace = pFaceResFT->rcFace;
        }
        
        if (nFaceNum == 2) {//双脸识别
            AFR_FSDK_FACEINPUT faceInput1 = {0};
            faceInput1.rcFace = pFaceResFT->rcFace[0];
            faceInput1.lOrient = pFaceResFT->lfaceOrient;
            
            AFR_FSDK_FACEINPUT faceInput2 = {0};
            faceInput2.rcFace = pFaceResFT->rcFace[1];
            faceInput2.lOrient = pFaceResFT->lfaceOrient;
            
            AFR_FSDK_FACEMODEL Model1 = [self getFaceModel:offscreen faceInput:faceInput1];
            AFR_FSDK_FACEMODEL Model2 = [self getFaceModel:offscreen faceInput:faceInput2];
            
            MFloat fMimilScore =  0.0;
            MRESULT mr = AFR_FSDK_FacePairMatching(_arcsoftFR, &Model1, &Model2, &fMimilScore);
            if (mr == MOK) {
                if(self.delegate && [self.delegate respondsToSelector:@selector(faceSimilarity:)])
                    [self.delegate faceSimilarity:fMimilScore];
//                NSLog([NSString stringWithFormat:@"相似度: %f",fMimilScore]);
            }
        }
    }
    
    NSMutableArray *arrayFaceRect = [NSMutableArray arrayWithCapacity:0];
    return arrayFaceRect;
}

- (BOOL)registerDetectedPerson:(NSString *)personName
{
    AFRPerson *registerPerson = self.frPerson;
    if(registerPerson == nil || registerPerson.registered)
        return NO;
    
    registerPerson.name = personName;
    registerPerson.Id = [self.frManager getNewPersonID];
    registerPerson.registered = [self.frManager addPerson:registerPerson];

    return registerPerson.registered;
}

- (LPASVLOFFSCREEN)copyOffscreenForProcess:(LPASVLOFFSCREEN)pOffscreenIn
{
    if (pOffscreenIn == MNull) {
        return  MNull;
    }
    
    if (_offscreenForProcess != NULL)
    {
        if (_offscreenForProcess->i32Width != pOffscreenIn->i32Width || _offscreenForProcess->i32Height != pOffscreenIn->i32Height || _offscreenForProcess->u32PixelArrayFormat != pOffscreenIn->u32PixelArrayFormat) {
            [Utility freeOffscreen:_offscreenForProcess];
            _offscreenForProcess = NULL;
        }
    }
    
    if (_offscreenForProcess == NULL) {
        _offscreenForProcess = [Utility createOffscreen:pOffscreenIn->i32Width  height:pOffscreenIn->i32Height format:pOffscreenIn->u32PixelArrayFormat];
    }
    
    if (ASVL_PAF_NV12 == pOffscreenIn->u32PixelArrayFormat
        || ASVL_PAF_NV21 == pOffscreenIn->u32PixelArrayFormat)
    {
        memcpy(_offscreenForProcess->ppu8Plane[0], pOffscreenIn->ppu8Plane[0], pOffscreenIn->i32Height * pOffscreenIn->pi32Pitch[0]) ;
        
        memcpy(_offscreenForProcess->ppu8Plane[1], pOffscreenIn->ppu8Plane[1], pOffscreenIn->i32Height * pOffscreenIn->pi32Pitch[1] / 2);
    }
    else if (ASVL_PAF_RGB32_R8G8B8A8 == pOffscreenIn->u32PixelArrayFormat
             || ASVL_PAF_RGB32_B8G8R8A8 == pOffscreenIn->u32PixelArrayFormat)
    {
        memcpy(_offscreenForProcess->ppu8Plane[0], pOffscreenIn->ppu8Plane[0], pOffscreenIn->i32Height * pOffscreenIn->pi32Pitch[0]) ;
        
    }
    
    return _offscreenForProcess;
}
@end
