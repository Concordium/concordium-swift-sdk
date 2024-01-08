//
// Created by Rene Hansen on 08/01/2024.
//

import Foundation

/// The equivalent of a Kotlin 'with' scoped function that allows us to set properties inline (especially useful for structs that have an empty initializer)
///
///
/// - Parameters:
///   - receiver: The object on which we want to call a block/closure
///   - block: The block to be called
/// - Returns: The modified object
/// Example:
/// ```
/// struct MyStruct {
///    var property1: String?
///    var property2: Int?
/// }
/// Usage
/// let myObject = with(MyStruct()) {
///    $0.property1 = "Hello"
///    $0.property2 = 42
/// ```
/// }
func with<T>(_ receiver: T, _ block: (inout T) -> Void) -> T {
    var copy = receiver
    block(&copy)
    return copy
}
