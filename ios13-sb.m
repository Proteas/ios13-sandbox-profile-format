//
//  main.m
//  ios13-sb
//
//  Created by Proteas on 2019/6/20.
//  Copyright © 2019 Proteas. All rights reserved.
//

#import <Foundation/Foundation.h>

void HexDump(char *description, void *addr, int len);

int main(int argc, const char * argv[])
{
    @autoreleasepool
    {
        if (argc != 3) {
            printf("Usage: ./ios13-sb sb_bundle.bin sb_ops.txt\n");
            exit(1);
        }
        
        NSString *sbOpStr = [NSString stringWithContentsOfFile:[NSString stringWithUTF8String:argv[2]]
                                                      encoding:NSUTF8StringEncoding error:NULL];
		if (sbOpStr == nil) {
            printf("[-] fail to load sb ops: %s\n", argv[2]);
            exit(1);
		}
        NSArray *sbOpList = [sbOpStr componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
        
        NSData *sbData = [NSData dataWithContentsOfFile:[NSString stringWithUTF8String:argv[1]]];
        if (sbData == nil) {
            printf("[-] fail to load sb bundle: %s\n", argv[1]);
            exit(1);
        }
        
        uint8_t *sbDataPtr = (uint8_t *)[sbData bytes];
        size_t sbDataLen = (size_t)[sbData length];
        printf("[+] data size: 0x%lx\n", sbDataLen);
        printf("\n");
		
		// offset: 0, version
        uint32_t ver = *((uint16_t *)sbDataPtr);
        printf("[+] version: 0x%x\n", ver);
        
        // offset: 2, op node size
        uint32_t opNodeSize = (*(uint16_t *)(sbDataPtr + 2)) * 8;
        printf("[+] op node size: 0x%x\n", opNodeSize);
        
        // offset: 4, sb operation count
        uint32_t sbOpCount = *(sbDataPtr + 4);
        printf("[+] sb operation count: %d\n", sbOpCount);
        
        // profile size
        uint32_t profileSize = sbOpCount * 2 + sizeof(uint16_t) + sizeof(uint16_t);
        printf("[+] profile size: %d\n", profileSize);
        
        // offset: 6, profile count
        uint32_t profileCount = *(uint16_t *)(sbDataPtr + 6);
        printf("[+] profile count: %d\n", profileCount);
        
        // offset: 8, regex item count
        uint32_t regexItemCount = *(uint16_t *)(sbDataPtr + 8);
        printf("[+] regex item count: %d\n", regexItemCount);
        
        // offset: 10, global var count
        uint32_t globalVarCount = *(sbDataPtr + 10);
        printf("[+] global var count: %d\n", globalVarCount);
        
        // offset: 11, message item count
        uint32_t msgItemCount = *(sbDataPtr + 11);
        printf("[+] message item count: %d\n", msgItemCount);
        
        // global var start
        uint32_t globalVarStart = 2 * regexItemCount + 12;
        printf("[+] global var start: 0x%x\n", globalVarStart);
        
        // global var end
        uint32_t globalVarEnd = globalVarStart + 2 * globalVarCount;
        printf("[+] global var end: 0x%x\n", globalVarEnd);
        
        // temp op node start
        uint32_t opNodeStartTmp = globalVarEnd + 2 * msgItemCount + profileSize * profileCount;
        printf("[+] temp op node start: 0x%x\n", opNodeStartTmp);
        
        // delta op node start
        uint32_t opNodeStartDelta = 8 - (opNodeStartTmp & 6);
        if (!(opNodeStartTmp & 6)) {
            opNodeStartDelta = 0;
        }
        printf("[+] delta op node start: 0x%x\n", opNodeStartDelta);
        
        // op node start
        uint32_t opNodeStart = opNodeStartDelta + opNodeStartTmp;
        printf("[+] op node start: 0x%x\n", opNodeStart);
        
        // start address of regex, global, messsages
        uint32_t baseAddr = opNodeStart + opNodeSize;
        printf("[+] start address of regex, global, messsages: 0x%x\n", baseAddr);
        printf("-----------------------------------------\n");
        
        // messages
        for (int idx = 0; idx < msgItemCount; ++idx) {
            uint16_t offset = *(uint16_t *)(sbDataPtr + globalVarEnd + idx * 2);
            uint32_t pos = baseAddr + 8 * offset;
            char *strPtr = (char *)(sbDataPtr + pos + 2);
            printf("[+] offset: 0x%04x, pos: 0x%x, %s\n", offset, pos, strPtr);
        }
        printf("-----------------------------------------\n");
        
        // global vars
        for (int idx = 0; idx < globalVarCount; ++idx) {
            uint16_t offset = *(uint16_t *)(sbDataPtr + globalVarStart + idx * 2);
            uint32_t pos = baseAddr + 8 * offset;
            char *strPtr = (char *)(sbDataPtr + pos + 2);
            printf("[+] offset: 0x%x, pos: 0x%x, %s\n", offset, pos, strPtr);
        }
        printf("-----------------------------------------\n");
        
        char tmpBuf[256] = {0};
        
        // regex table
        for (int idx = 0; idx < regexItemCount; ++idx) {
            uint32_t offset = 12 + 2 * idx;
            uint16_t tblOffset = *(uint16_t *)(sbDataPtr + offset);
            uint32_t itemLocation = 8 * tblOffset;
            uint32_t itemOffset = baseAddr + itemLocation;
            uint16_t *itemLengthPtr = (uint16_t *)(sbDataPtr + itemOffset);
            uint32_t itemLength = *itemLengthPtr;
            printf("[+][REGEX] idx: %03d, offset: 0x%x, location: 0x%x, length: 0x%x\n", idx, itemOffset, itemLocation, itemLength);
            memset(tmpBuf, 0, 256);
            sprintf(tmpBuf, "0x%X", itemLocation);
            HexDump(tmpBuf, itemLengthPtr + 1, itemLength);
            printf("-----------------------------------------\n");
        }
        
        // op node range and count
        uint32_t opNodeEnd = baseAddr;
        uint32_t opNodeCount = (opNodeEnd - opNodeStart) / 8;
        printf("[+] op node start: 0x%x\n", opNodeStart);
        printf("[+] op node end: 0x%x\n", opNodeEnd);
        printf("[+] op node count: %d\n", opNodeCount);
        printf("-----------------------------------------\n");
        
        // op node values
        uint64_t *opNodes = (uint64_t *)malloc(opNodeCount * sizeof(uint64_t));
        memset(opNodes, 0, opNodeCount * sizeof(uint64_t));
        
        // op nodes
        for (int idx = 0; idx < opNodeCount; ++idx) {
            uint32_t opNodeOffset = opNodeStart + 8 * idx;
            uint64_t opNodeVal = *(uint64_t *)(sbDataPtr + opNodeOffset);
            printf("[+] op node index: 0x%04x, value: 0x%016llx\n", idx, opNodeVal);
            opNodes[idx] = opNodeVal;
        }
        
        // profiles
        uint32_t profileBase = globalVarStart + 2 * globalVarCount + 2 * msgItemCount;
        for (int idxProfile = 0; idxProfile < profileCount; ++idxProfile) {
            uint16_t nameOffset = *(uint16_t *)(sbDataPtr + profileBase);
            uint32_t namePos = baseAddr + 8 * nameOffset;
            uint16_t strSize = *(uint16_t *)(sbDataPtr + namePos);
            uint8_t *strAddr = sbDataPtr + namePos + 2;
            memset(tmpBuf, 0, 256);
            memcpy(tmpBuf, strAddr, strSize);
            uint16_t ver = *(uint16_t *)(sbDataPtr + profileBase + 2);
            printf("[+] 0x%x: %s, ver: 0x%x\n", namePos, tmpBuf, ver);
            
            uint16_t *profileOpBase = (uint16_t *)(sbDataPtr + profileBase + 4);
            for (int idxOp = 0; idxOp < sbOpCount; ++idxOp) {
                uint16_t opValIndex = profileOpBase[idxOp];
                uint64_t opVal = opNodes[opValIndex];
                printf("  name: %s, index: 0x%x, value: 0x%016llx\n", ((NSString *)sbOpList[idxOp]).UTF8String, opValIndex, opVal);
            }
            printf("-----------------------------------------\n");
            profileBase += profileSize;
        }
        
        // clear
        free(opNodes);
    }
    
    return 0;
}

void HexDump(char *description, void *addr, int len)
{
    int idx;
    unsigned char buff[17];
    unsigned char *pc = (unsigned char *)addr;
    
    // Output description if given.
    if (description != NULL)
        printf ("%s:\n", description);
    
    // Process every byte in the data.
    for (idx = 0; idx < len; idx++) {
        // Multiple of 16 means new line (with line offset).
        
        if ((idx % 16) == 0) {
            // Just don't print ASCII for the zeroth line.
            if (idx != 0)
                printf (" | %s\n", buff);
            
            // Output the offset.
            printf ("  %04X:", idx);
        }
        
        // Now the hex code for the specific character.
        printf (" %02X", pc[idx]);
        
        // And store a printable ASCII character for later.
        if ((pc[idx] < 0x20) || (pc[idx] > 0x7e))
            buff[idx % 16] = '.';
        else
            buff[idx % 16] = pc[idx];
        buff[(idx % 16) + 1] = '\0';
    }
    
    // Pad out last line if not exactly 16 characters.
    while ((idx % 16) != 0) {
        printf ("   ");
        idx++;
    }
    
    // And print the final ASCII bit.
    printf (" | %s\n", buff);
}
