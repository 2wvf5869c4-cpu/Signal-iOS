//
// Copyright 2026 Signal Messenger, LLC
// SPDX-License-Identifier: AGPL-3.0-only
//

import XCTest
import GRDB

@testable import SignalServiceKit

final class TSAccountManagerImplMultiAccountTest: XCTestCase {
    private var db: InMemoryDB!
    private var tsAccountManager: TSAccountManagerImpl!

    override func setUp() {
        db = InMemoryDB()
        tsAccountManager = TSAccountManagerImpl(
            appReadiness: AppReadinessMock(),
            dateProvider: Date.provider,
            databaseChangeObserver: DatabaseChangeObserverMock(),
            db: db,
        )
    }

    func testStoresAndSwitchesAccounts() {
        let accountAci1 = Aci.constantForTesting("00000000-0000-4000-8000-0000000000A1")
        let accountPni1 = Pni.constantForTesting("PNI:00000000-0000-4000-8000-0000000000B1")
        let accountPhone1 = E164("+16505550101")!

        let accountAci2 = Aci.constantForTesting("00000000-0000-4000-8000-0000000000A2")
        let accountPni2 = Pni.constantForTesting("PNI:00000000-0000-4000-8000-0000000000B2")
        let accountPhone2 = E164("+16505550102")!

        db.write { tx in
            tsAccountManager.initializeLocalIdentifiers(
                aci: accountAci1,
                phoneNumber: (accountPhone1, accountPni1),
                deviceId: .primary,
                serverAuthToken: "token-1",
                tx: tx,
            )
        }

        db.write { tx in
            tsAccountManager.initializeLocalIdentifiers(
                aci: accountAci2,
                phoneNumber: (accountPhone2, accountPni2),
                deviceId: .primary,
                serverAuthToken: "token-2",
                tx: tx,
            )
        }

        db.read { tx in
            XCTAssertEqual(tsAccountManager.allLocalIdentifiers(tx: tx).count, 2)
            XCTAssertEqual(tsAccountManager.localIdentifiers(tx: tx)?.aci, accountAci2)
        }

        db.write { tx in
            XCTAssertTrue(tsAccountManager.switchToAccount(aci: accountAci1, tx: tx))
        }

        db.read { tx in
            XCTAssertEqual(tsAccountManager.localIdentifiers(tx: tx)?.aci, accountAci1)
            XCTAssertEqual(tsAccountManager.storedServerAuthToken(tx: tx), "token-1")
        }
    }

    func testRemoveAccountUpdatesActiveAccount() {
        let accountAci1 = Aci.constantForTesting("00000000-0000-4000-8000-0000000000A3")
        let accountPni1 = Pni.constantForTesting("PNI:00000000-0000-4000-8000-0000000000B3")
        let accountPhone1 = E164("+16505550103")!

        let accountAci2 = Aci.constantForTesting("00000000-0000-4000-8000-0000000000A4")
        let accountPni2 = Pni.constantForTesting("PNI:00000000-0000-4000-8000-0000000000B4")
        let accountPhone2 = E164("+16505550104")!

        db.write { tx in
            tsAccountManager.initializeLocalIdentifiers(
                aci: accountAci1,
                phoneNumber: (accountPhone1, accountPni1),
                deviceId: .primary,
                serverAuthToken: "token-3",
                tx: tx,
            )
            tsAccountManager.initializeLocalIdentifiers(
                aci: accountAci2,
                phoneNumber: (accountPhone2, accountPni2),
                deviceId: .primary,
                serverAuthToken: "token-4",
                tx: tx,
            )
        }

        db.write { tx in
            tsAccountManager.removeAccount(aci: accountAci2, tx: tx)
        }

        db.read { tx in
            XCTAssertEqual(tsAccountManager.localIdentifiers(tx: tx)?.aci, accountAci1)
            XCTAssertEqual(tsAccountManager.storedServerAuthToken(tx: tx), "token-3")
            XCTAssertEqual(tsAccountManager.allLocalIdentifiers(tx: tx).map(\.aci), [accountAci1])
        }

        db.write { tx in
            tsAccountManager.removeAccount(aci: accountAci1, tx: tx)
        }

        db.read { tx in
            XCTAssertNil(tsAccountManager.localIdentifiers(tx: tx))
            XCTAssertTrue(tsAccountManager.allLocalIdentifiers(tx: tx).isEmpty)
            XCTAssertEqual(tsAccountManager.registrationState(tx: tx), .unregistered)
        }
    }
}

private final class DatabaseChangeObserverMock: DatabaseChangeObserver {
    func beginObserving(pool: GRDB.DatabasePool) throws {}
    func stopObserving(pool: GRDB.DatabasePool) throws {}

    func disable<T>(tx: DBWriteTransaction, during: (DBWriteTransaction) throws -> T) rethrows -> T {
        try during(tx)
    }

    @MainActor
    func appendDatabaseChangeDelegate(_ databaseChangeDelegate: any DatabaseChangeDelegate) {}

#if TESTABLE_BUILD
    func appendDatabaseWriteDelegate(_ delegate: any DatabaseWriteDelegate) {}
#endif
}
