1. Run install\_abi\_tools.sh to install all the necessary command line tools.  This should only need to be run once.
2. Next run the patch\_releases.sh script to download the traffic server releases that need to be patched.  Again this should only need to be run once.
3. Run the abi.sh script to download the rest of the releases, build all releases, and check for ABI compatibility.  This script can be run multiple time and it will automatically update the traffic server GitHub master branch to see if it is still ABI compatible

