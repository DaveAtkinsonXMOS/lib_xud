// Copyright 2011-2021 XMOS LIMITED.
// This Software is subject to the terms of the XMOS Public Licence: Version 1.
// r10: EP number
// OUT Token Packet -----------------------------------------------------------------------------
#include "XUD_AlignmentDefines.h"

.align FUNCTION_ALIGNMENT
.skip 0
Pid_Out:
    #include "XUD_CrcAddrCheck.S"
    ldw        r3, r5[r10]                      // Load relevant EP pointer
    bf         r3, XUD_TokenOut_BufferFull
    ldw        r1, r3[3]                        // Load buffer from EP structure

CheckEpTypeOut:
    ldw        r11, r3[5]                       // Load EP type
    BRFT_ru6   r11, DoOutNonIso                 // ISO endpoint

OutReady:
    stw        r11, r5[r10]                     // Clear ready straight away - we don't to CRC checking on Iso - else we would have to wait for end of packet
    bl         doRXData
    clre

InformEP_Iso:                                   // Iso EP - no handshake
    ldw         r11, r3[1]                      // Load EP chanend
    {out        res[r11], r4;   ldw    r7, sp[STACK_TXCRC_INIT]} // Output datalength (words) & CRC 16 Init (IN) 
    {outt       res[r11], r8;   ldw    r6, sp[STACK_RXCRC_INIT]} // CRC16 init (out) - Needs reseting after an out & Send tail length
#ifndef __XS3A__
    ldw         r1, sp[STACK_VTOK_PORT]
#endif
    #include "XUD_TokenJmp.S"

.align FUNCTION_ALIGNMENT
.skip 0
DoOutNonIso:
    bl         doRXData
    {clre;     eq         r1, r6, r11}          // Check for good CRC16

doRXDataReturn_NonIso:
    bf         r1, NextTokenAfterOut            // Check for bad crc

    ldaw       r6,  dp[handshakeTable_OUT]      // Load the handshake table.
   {ldw        r11, r6[r10]                     // Get the handshake PID for this EP
    ldc        r1,  USB_PIDn_STALL}             // as well as the STALL PID
    eq         r1,  r11, r1                     // and compare them.
    nop                                         // NOP to ensure minimum interpacket delay.
    bt         r1,  XUD_TokenOut_Handshake      // If the handshake PID for this EP is STALL, then
                                                // go and send the handshake without clearing ready
                                                // or communicating back to the application that
                                                // the packet has been received.

    ldc        r11, USB_PIDn_ACK                // Data CRC good, EP not Iso, and EP not halted: Send Ack
    outpw      res[TXD], r11, 8
    syncr      res[TXD]

StoreTailDataOut:
    ldc        r11, 0
    stw        r11, r5[r10]                     // Clear ready
    ldw        r11, r3[1]                       // Load EP chanend

    out        res[r11], r4                     // Output datalength (words)
    outt       res[r11], r8                     // Send tail length

    bu        NextTokenAfterOut

// Various Error handling functions -------------------------------------------------------------------
.align FUNCTION_ALIGNMENT
Err_RxErr:                                      // RxError signal high during data packet receive:
    DUALENTSP_lu6 0
    clrsr     3
    clre
    ldw       r10, sp[STACK_RXE_PORT]           // Read out data from RxE port
    in        r11, res[r10]
    eeu       res[r10]
    ldw       r10, sp[STACK_RXA_PORT]
    in        r11, res[r10]                     // Wait for rxa low and ignore packet (let transaction timout)
    setsr     3                                 // Re-enable thread interrupts
    bu        NextToken

XUD_TokenOut_BufferFull:
  ldw       r9, sp[STACK_RXA_PORT]
  setc      res[r9], XS1_SETC_RUN_CLRBUF
  setc      res[r9], XS1_SETC_COND_NEQ

XUD_TokenOut_WaitForPacketEnd:                  // Wait for end of data then send NAK
  in        r11, res[r9]
  setc      res[r9], XS1_SETC_COND_EQ
  in        r11, res[r9]
                                                // TODO: Observe interpacket delay
#ifndef XUD_NAK_ISO_OUT
  ldw       r4, sp[STACK_EPTYPES_OUT]           // Load ep type table
  ldw       r4, r4[r10]                         // load EP type
  bf        r4, PrimaryBufferFull_NoNak
#endif

  // Load handshake (ACK or STALL)
  ldaw      r6, dp[handshakeTable_OUT]          // Load handshake table
XUD_TokenOut_Handshake:
  ldw       r11, r6[r10]
  outpw     res[TXD], r11, 8
  syncr     res[TXD]

PrimaryBufferFull_NoNak:
  setc      res[RXD], XS1_SETC_RUN_CLRBUF
  bu        NextToken

// Timedout waiting for data after OUT... go back to waiting for tokens
//OutDataTimeOut:
  //clre
  //bl	ERR_OutDataTimeout
  //bu        NextToken



