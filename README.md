# CrowdStrike BSOD Recovery USB
`Unofficial`

![Banner](https://github.com/the-it-chronicles/crowdstrike-bsod-recovery/blob/main/media/CS_BSOD_Banner.png)

## About

This project was developed to provide staff with a simple USB drive pre-loaded with all of our BitLocker keys to deploy the CrowdStrike BSOD fix to physical machines.

This is **NOT** an official solution. It was developed by a third party out of necessity.

## Usage

A csv file containing the exported BitLocker id and key pairs is copied to the root of the USB drive before placing it into an affected computer and booting from USB. Upon booting, a script automatically unlocks the BitLocker encryption and deletes the offending .sys file before prompting the user to restart.

## Setup

For instructions on how to make your own. See the following blog post.
[https://theitchronicles.wordpress.com/2024/07/21/crowdstrike-bsod-recovery/](https://theitchronicles.wordpress.com/2024/07/21/crowdstrike-bsod-recovery/)