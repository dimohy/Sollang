struct OwnedNode {
    payload: box Int
}

main {
    [OwnedNode; ~] => nodes!
    OwnedNode { payload: box 7 } => node!
    nodes! -> push(node!)
    node!.payload
}
