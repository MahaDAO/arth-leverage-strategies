const { BigNumber } = require('ethers')


exports.sendTransaction = async (
  transaction,
  wallet
) => {
    if (transaction.value) {
        transaction.value = BigNumber.from(transaction.value)
      }
      const txRes = await wallet.sendTransaction(transaction)
    
      let receipt = null
      const provider = wallet.provider
      if (!provider) {
        return 'Failed'
      }
    
      while (receipt === null) {
        try {
          receipt = await provider.getTransactionReceipt(txRes.hash)
    
          if (receipt === null) {
            continue
          }
        } catch (e) {
          console.log(`Receipt error:`, e)
          break
        }
      }
    
      // Transaction was successful if status === 1
      if (receipt) {
        return 'Sent'
      } else {
        return 'Failed'
      }
}

