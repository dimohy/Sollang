struct Key {
    id: Int
}

trait Hash { hash: self -> Int }
trait Eq { eq: self -> Int }
impl Hash for Key { hash: self -> Int => self.id }
impl Eq for Key { eq: self -> Int => self.id }

main {
    { Key { id: 2 }: 10 } => values
    values[{ id: 2, extra: 3 }] => found
}
