#!/usr/bin/env bash

ALICE=$(bondscli keys show alice --keyring-backend=test -a)
BOB=$(bondscli keys show bob --keyring-backend=test -a)
FEE=$(bondscli keys show fee --keyring-backend=test -a)

# Visual representation of bonding curve:
# https://www.desmos.com/calculator/2ael5dojku

# Create a Power Function bonding curve
# token: 発行するトークンの単位
# function-type: bonding curveのfunction
# function-parameters: functionに必要な引数をセット
# max-supply: 発行するトークンの上限
# reserve-tokens: どんなtokenを受け取って、今回のトークン(mytoken)を発行するか
# tx-fee-percentage: 購入・売却どちらかに関係なく、取引自体があった場合に発生するfee
# exit-fee-percentage: 売却時にのみ発生するfee
# fee-address: 手数料が送られるアドレス(dapps運営元)
# 上記で設定しているfeeはgas代とは別。
# https://docs.ixo.foundation/alphabond/tutorials/01_standard#mint-to-deposit

# order-quantity-limits: 一度の取引でやり取りできるトークン量の上限
# batch-blocks: batch-blocksごとにこのトークン売買が処理される。これはフロントランニングを防ぐためのもの。
# バッチ処理を行い、一つのバッチ処理で、全ての書い手・売り手に別々の値段を提示するのではなく、統一の値段を提供する
# https://billyrennekamp.medium.com/batched-bonding-curves-ce69a57d8ae4

# sanity-rate、sanity-margin-percentage: function-typeでswapper関数を設定したときに必要になる
# allow-sells: 売りを有効にするか
# signers: 売りに足して誰が署名をするのか
# from: 売られたら誰からtokenが送られてくるかと思われる
# https://docs.ixo.foundation/alphabond/spec/07_functions_library
# https://docs.ixo.foundation/alphabond/tutorials/01_standard
bondscli tx bonds create-bond \
  --token=mytoken \
  --name="My Token" \
  --description="My first continuous token" \
  --function-type=power_function \
  --function-parameters="m:12,n:2,c:100" \
  --reserve-tokens=uatom \
  --tx-fee-percentage=0 \
  --exit-fee-percentage=0 \
  --fee-address="$FEE" \
  --max-supply=1000000mytoken \
  --order-quantity-limits="" \
  --sanity-rate="0" \
  --sanity-margin-percentage="0" \
  --allow-sells \
  --signers="$ALICE" \
  --batch-blocks=3 \
  --from alice --keyring-backend=test --broadcast-mode block -y
# Query the created bond
bondscli q bonds bond mytoken
# We can keep an eye on the batch
watch -n 1 bondscli q bonds batch mytoken

# Query the price of buying 10mytoken
bondscli q bonds buy-price 10mytoken
# Query the token price at supply=10mytoken
bondscli q bonds price 10mytoken

# Buy 10mytoken from alice with max spend of 1000000uatom
# 最大消費額(1000000uatom)は実際の買い価格(bondscli q bonds buy-price 10mytoken)よりも多めに設定する
# https://docs.ixo.foundation/alphabond/tutorials/01_standard#mint-to-deposit
bondscli tx bonds buy 10mytoken 1000000uatom --from alice --keyring-backend=test --broadcast-mode block -y
# Wait for order to get processed
sleep 21
# Query alice's account
bondscli q account "$ALICE"

# Query the price of buying 10mytoken
bondscli q bonds buy-price 10mytoken
# Query the token price at supply=20mytoken
bondscli q bonds price 20mytoken

# Buy 10mytoken from bob with max spend of 1000000uatom
bondscli tx bonds buy 10mytoken 1000000uatom --from bob --keyring-backend=test --broadcast-mode block -y
# Wait for order to get processed
sleep 21
# Query bob's account
bondscli q account "$BOB"

# Sell 10mytoken from alice at a profit :]
bondscli tx bonds sell 10mytoken --from alice --keyring-backend=test --broadcast-mode block -y
# Wait for order to get processed
sleep 21
# Query alice's account
bondscli q account "$ALICE"

# Sell 10mytoken from bob at a loss :[
bondscli tx bonds sell 10mytoken --from bob --keyring-backend=test --broadcast-mode block -y
# Wait for order to get processed
sleep 21
# Query bob's account
bondscli q account "$BOB"