/**
 * Smoke tests for the scheduling console facade: delegates to existing HC invocables only.
 */
@IsTest
private class HC_SchedulingConsoleControllerTest {
    @IsTest
    static void getFacilities_returnsRowsMap() {
        Test.startTest();
        Map<String, Object> m = HC_SchedulingConsoleController.getFacilities('');
        Test.stopTest();
        System.assertEquals(true, m.containsKey('rows'));
        System.assertEquals(true, m.containsKey('success'));
    }

    @IsTest
    static void findSpecialists_returnsRowsMap() {
        Test.startTest();
        Map<String, Object> m = HC_SchedulingConsoleController.findSpecialists('', '', 5);
        Test.stopTest();
        System.assertEquals(true, m.containsKey('rows'));
    }

    @IsTest
    static void routeSymptom_returnsMap() {
        Test.startTest();
        Map<String, Object> m = HC_SchedulingConsoleController.routeSymptomToSpecialty('headache', 'TestCity');
        Test.stopTest();
        System.assertNotEquals(null, m);
    }

    @IsTest
    static void listPatientVisits_requiresPatient() {
        Test.startTest();
        Map<String, Object> m = HC_SchedulingConsoleController.listPatientVisitsForConsole('', '', '');
        Test.stopTest();
        System.assertEquals(false, m.get('success'));
        System.assert(((List<Object>) m.get('rows')).isEmpty());
    }
}
