# Verify all patterns from spec
spec = {
    0x0: "a b c d e f",
    0x1: "b c",
    0x2: "a b d e g",
    0x3: "a b c d g",
    0x4: "b c f g",
    0x5: "a c d f g",
    0x6: "a c d e f g",
    0x7: "a b c",
    0x8: "a b c d e f g",
    0x9: "a b c d f g",
    0xA: "a b c e f g",
    0xB: "c d e f g",
    0xC: "a d e f",
    0xD: "b c d e g",
    0xE: "a d e f g",
    0xF: "a e f g",
}

# Map segments to bit indices
segments = {'a': 0, 'b': 1, 'c': 2, 'd': 3, 'e': 4, 'f': 5, 'g': 6}

code_patterns = {
    0x0: 0b0111111,
    0x1: 0b0000110,
    0x2: 0b1011011,
    0x3: 0b1001111,
    0x4: 0b1100110,
    0x5: 0b1101101,
    0x6: 0b1111101,
    0x7: 0b0000111,
    0x8: 0b1111111,
    0x9: 0b1101111,
    0xA: 0b1110111,
    0xB: 0b1111100,
    0xC: 0b0111001,
    0xD: 0b1011110,
    0xE: 0b1111001,
    0xF: 0b1110001,
}

print("Verifying patterns:")
print("Hex Spec                 Expected   Code Pat   Code Out   Match")
print("-" * 65)

errors = 0
for hex_val in range(16):
    lit_segments = spec[hex_val].split()
    lit_indices = {segments[s] for s in lit_segments}
    
    # Build expected output: 0 for lit, 1 for not lit (active-low)
    expected = 0
    for bit in range(7):
        if bit not in lit_indices:
            expected |= (1 << bit)
    
    code_pat = code_patterns[hex_val]
    code_out = ~code_pat & 0x7F  # Invert and mask to 7 bits
    
    match = code_out == expected
    if not match:
        errors += 1
    
    match_str = "OK" if match else "FAIL"
    
    print(f"{hex_val:X}   {spec[hex_val]:<20} {expected:07b}       {code_pat:07b}       {code_out:07b}       {match_str}")

if errors > 0:
    print(f"\nFound {errors} errors")
else:
    print("\nAll patterns correct!")
