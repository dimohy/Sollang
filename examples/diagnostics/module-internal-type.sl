import sample.internal_type as hidden

main {
    hidden.Secret { value: 1 } => secret
    secret.value -> println
}
