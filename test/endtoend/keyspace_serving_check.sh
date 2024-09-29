function checkKeyspaceServing() {
  ks=$1
  shard=$2
  nb_of_replica=$3
  out=$(mysql -h 127.0.0.1 -u user --table --execute="show vitess_tablets")
  numtablets=$(echo "$out" | grep -E "$ks(.*)$shard(.*)PRIMARY(.*)SERVING|$ks(.*)$shard(.*)REPLICA(.*)SERVING|$ks(.*)$shard(.*)RDONLY(.*)SERVING" | wc -l)
  if [[ $numtablets -ge $((nb_of_replica+1)) ]]; then
    echo "Shard $ks/$shard is serving"
    exit 0
  else
    echo "Shard $ks/$shard is not fully serving. Output: $out"
    exit 1
  fi
}

checkKeyspaceServing main-test - 1