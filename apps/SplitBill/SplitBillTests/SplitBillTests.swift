import Testing
@testable import SplitBill

struct SplitBillTests {
    @Test("Verificar inicialización del entorno de pruebas")
    func environmentSanityCheck() {
        #expect(1 + 1 == 2)
    }
}
