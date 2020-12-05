pub fn numDigits(num: u32) u8 {
    var x = num;
    var count: u8 = 0;
    while (x != 0) {
        x /= 10;
        count += 1;
    }
    return count;
}
