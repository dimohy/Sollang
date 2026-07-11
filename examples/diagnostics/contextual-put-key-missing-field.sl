struct Key {
    scope: Int
    id: Int
}

trait Hash { hash: self -> Int }
trait Eq { eq: self -> Int }
impl Hash for Key { hash: self -> Int => self.scope + self.id }
impl Eq for Key { eq: self -> Int => self.scope * 100 + self.id }

main {
    {Key: Text; { scope: 1, id: 1 }: "one"} => values!
    values! -> put({ scope: 2 }, "two")
}
