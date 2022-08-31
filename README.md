# Smart-Contract-Rewards
Solidity smart contract for CAKE rewards


claim - any holder can claim their rewards in CAKE

getUnpaidEarning(address holder) - function to check the balance payable

When the wallet withdraws its balance, the above function is reset
It only counts new balances again if the contract receives more CAKE for payment of cakes
The contract must and can only receive CAKE directly. Upon receipt, he will update the balances payable.
You should not send BNB for the contract


There are also other functions to know the accounts that have already withdrawn, how much they have withdrawn...
