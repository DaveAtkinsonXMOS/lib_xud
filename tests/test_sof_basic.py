#!/usr/bin/env python
# Copyright 2019-2021 XMOS LIMITED.
# This Software is subject to the terms of the XMOS Public Licence: Version 1.
import xmostest
from usb_packet import *
import usb_packet
from helpers import do_usb_test, RunUsbTest, CreateSofToken
from usb_session import UsbSession
from usb_transaction import UsbTransaction


def do_test(arch, clk, phy, data_valid_count, usb_speed, seed, verbose=False):

    address = 1
    ep = 1
    frameNumber = 52  # Note, for frame number 52 we expect A5 34 40 on the bus

    session = UsbSession(
        bus_speed=usb_speed, run_enumeration=False, device_address=address
    )

    # Start with a valid transaction */
    session.add_event(
        UsbTransaction(
            session,
            deviceAddress=address,
            endpointNumber=ep,
            endpointType="BULK",
            direction="OUT",
            dataLength=10,
        )
    )

    session.add_event(CreateSofToken(frameNumber, data_valid_count))
    session.add_event(CreateSofToken(frameNumber + 1, data_valid_count))
    session.add_event(CreateSofToken(frameNumber + 2, data_valid_count))
    session.add_event(CreateSofToken(frameNumber + 3, data_valid_count))
    session.add_event(CreateSofToken(frameNumber + 4, data_valid_count))

    # Finish with valid transaction
    session.add_event(
        UsbTransaction(
            session,
            deviceAddress=address,
            endpointNumber=ep,
            endpointType="BULK",
            direction="OUT",
            dataLength=11,
            interEventDelay=6000,
        )
    )

    do_usb_test(
        arch,
        clk,
        phy,
        usb_speed,
        [session],
        __file__,
        seed,
        level="smoke",
        extra_tasks=[],
        verbose=verbose,
    )


def runtest():
    RunUsbTest(do_test)
