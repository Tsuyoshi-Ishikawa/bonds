#!/usr/bin/env bash

PASSWORD="12345678"
MIGUEL=$(yes $PASSWORD | bondscli keys show miguel -a)
FRANCESCO=$(yes $PASSWORD | bondscli keys show francesco -a)
SHAUN=$(yes $PASSWORD | bondscli keys show shaun -a)
RESERVE=$(yes $PASSWORD | bondscli keys show reserve -a)
FEE=$(yes $PASSWORD | bondscli keys show fee -a)

wait() {
  echo "Waiting for chain to start..."
  while :; do
    RET=$(bondscli status 2>&1)
    if [[ ($RET == ERROR*) || ($RET == *'"latest_block_height": "0"'*) ]]; then
      sleep 1
    else
      echo "A few more seconds..."
      sleep 6
      break
    fi
  done
}

tx_from_m() {
  cmd=$1
  shift
  yes $PASSWORD | bondscli tx bonds "$cmd" --from miguel -y --broadcast-mode block "$@"
}

tx_from_f() {
  cmd=$1
  shift
  yes $PASSWORD | bondscli tx bonds "$cmd" --from francesco -y --broadcast-mode block "$@"
}

create_bond_multisig() {
  bondscli tx bonds create-bond \
    --token=abc \
    --name="A B C" \
    --description="Description about A B C" \
    --function-type=power_function \
    --function-parameters="m:12,n:2,c:100" \
    --reserve-tokens=res \
    --reserve-address="$RESERVE" \
    --tx-fee-percentage=0.5 \
    --exit-fee-percentage=0.1 \
    --fee-address="$FEE" \
    --max-supply=1000000abc \
    --order-quantity-limits="" \
    --sanity-rate="" \
    --sanity-margin-percentage="" \
    --allow-sells=true \
    --signers="$(bondscli keys show francesco -a),$(bondscli keys show shaun -a)" \
    --batch-blocks=1 \
    --from="$MIGUEL" -y --broadcast-mode block --generate-only >multisig.json
  yes $PASSWORD | bondscli tx sign multisig.json --from=francesco --output-document=multisig.json
  yes $PASSWORD | bondscli tx sign multisig.json --from=shaun --output-document=multisig.json
  bondscli tx broadcast multisig.json
  rm multisig.json
}

edit_bond_multisig_incorrect_signers_1() {
  bondscli tx bonds edit-bond \
    --token=abc \
    --name="(1) New A B C" \
    --description="(1) New description about A B C" \
    --signers="$(bondscli keys show shaun -a),$(bondscli keys show francesco -a)" \
    --from="$MIGUEL" -y --broadcast-mode block --generate-only >multisig.json
  yes $PASSWORD | bondscli tx sign multisig.json --from=shaun --output-document=multisig.json
  yes $PASSWORD | bondscli tx sign multisig.json --from=francesco --output-document=multisig.json
  bondscli tx broadcast multisig.json
  rm multisig.json
}

edit_bond_multisig_incorrect_signers_2() {
  bondscli tx bonds edit-bond \
    --token=abc \
    --name="(2) New A B C" \
    --description="(2) New description about A B C" \
    --signers="$FRANCESCO" \
    --from="$MIGUEL" -y --broadcast-mode block --generate-only >multisig.json
  yes $PASSWORD | bondscli tx sign multisig.json --from=francesco --output-document=multisig.json
  bondscli tx broadcast multisig.json
  rm multisig.json
}

edit_bond_multisig_correct_signers() {
  bondscli tx bonds edit-bond \
    --token=abc \
    --name="(3) New A B C" \
    --description="(3) New description about A B C" \
    --signers="$(bondscli keys show francesco -a),$(bondscli keys show shaun -a)" \
    --from="$MIGUEL" -y --broadcast-mode block --generate-only >multisig.json
  yes $PASSWORD | bondscli tx sign multisig.json --from=francesco --output-document=multisig.json
  yes $PASSWORD | bondscli tx sign multisig.json --from=shaun --output-document=multisig.json
  bondscli tx broadcast multisig.json
  rm multisig.json
}

RET=$(bondscli status 2>&1)
if [[ ($RET == ERROR*) || ($RET == *'"latest_block_height": "0"'*) ]]; then
  wait
fi

echo "Creating bond..."
create_bond_multisig
echo "Waiting a bit..."
sleep 5
echo "Created bond..."
bondscli query bonds bond abc

echo "Editing bond with incorrect signers..."
edit_bond_multisig_incorrect_signers_1
echo "Waiting a bit..."
sleep 5
bondscli query bonds bond abc
echo "Bond was NOT edited!"

echo "Editing bond with incorrect signers again..."
edit_bond_multisig_incorrect_signers_2
echo "Waiting a bit..."
sleep 5
bondscli query bonds bond abc
echo "Bond was NOT edited!"

echo "Editing bond with correct..."
edit_bond_multisig_correct_signers
echo "Waiting a bit..."
sleep 5
bondscli query bonds bond abc
echo "Bond was edited!"
