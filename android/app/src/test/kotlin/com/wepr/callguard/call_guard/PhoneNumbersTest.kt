package com.wepr.callguard.call_guard

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class PhoneNumbersTest {
    @Test
    fun recognizesOnlyExactEmergencyCodesAfterCleaningOptionalPrefixes() {
        listOf("101", "102", "103", "104", "112", "911", "999").forEach {
            assertTrue("$it should be an emergency code", PhoneNumbers.isEmergencyServiceNumber(it))
        }
        assertTrue(PhoneNumbers.isEmergencyServiceNumber("1-01"))
        assertTrue(PhoneNumbers.isEmergencyServiceNumber("+1 12"))
        assertTrue(PhoneNumbers.isEmergencyServiceNumber("00-911"))

        assertFalse(PhoneNumbers.isEmergencyServiceNumber("1010"))
        assertFalse(PhoneNumbers.isEmergencyServiceNumber("9101"))
        assertFalse(PhoneNumbers.isEmergencyServiceNumber("9991"))
    }

    @Test
    fun detectsShortNumbersByDigitCountBeforeCountryCodeNormalization() {
        assertFalse(PhoneNumbers.isShortNumber("7"))
        assertTrue(PhoneNumbers.isShortNumber("11"))
        assertTrue(PhoneNumbers.isShortNumber("3700"))
        assertTrue(PhoneNumbers.isShortNumber("4-66"))
        assertTrue(PhoneNumbers.isShortNumber("080050"))
        assertTrue(PhoneNumbers.isShortNumber("+3700"))
        assertTrue(PhoneNumbers.isShortNumber("00 3700"))
        assertTrue(PhoneNumbers.isShortNumber("ABC3700"))

        assertFalse(PhoneNumbers.isShortNumber("112"))
        assertFalse(PhoneNumbers.isShortNumber("1234567"))
        assertFalse(PhoneNumbers.isShortNumber("1234567890"))
    }
}
