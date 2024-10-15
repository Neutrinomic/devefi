import ICRC55 "../src/ICRC55";
import Node "../src/node";
import Result "mo:base/Result";
import Array "mo:base/Array";
import Nat8 "mo:base/Nat8";
import Debug "mo:base/Debug";
import U "../src/utils";
import Option "mo:base/Option";
import Billing "./billing_all";

module {

    public func meta(all_ledgers : [ICRC55.SupportedLedger]) : ICRC55.NodeMeta {
        {
            billing = billing();
            id = "borrow"; // This has to be same as the variant in vec.custom
            name = "Borrow";
            description = "Borrow X tokens while providing Y tokens collateral";
            supported_ledgers = all_ledgers;
            version = #alpha;
            create_allowed = true;
        };
    };

    public func billing() : ICRC55.Billing {
        Billing.get();
    };

    public func authorAccount() : ICRC55.Account {
        Billing.authorAccount();
    };

    // Internal vector state
    public type Mem = {
        init : {
            ledger_borrow : Principal;
            ledger_collateral : Principal;
        };
        variables : {
            var interest : Nat;
        };
        internals : {};
    };

    // Create request
    public type CreateRequest = {
        init : {
            ledger_borrow : Principal;
            ledger_collateral : Principal;
        };
        variables : {
            interest : Nat;
        };
    };

    // Create state from request
    public func createRequest2Mem(t : CreateRequest) : Mem {
        {
            init = t.init;
            variables = {
                var interest = t.variables.interest;
            };
            internals = {};
        };
    };

    public func defaults(all_ledgers : [ICRC55.SupportedLedger]) : CreateRequest {
        let #ic(ledger_borrow) = all_ledgers[0] else Debug.trap("No ledgers found");
        let #ic(ledger_collateral) = all_ledgers[1] else Debug.trap("No ledgers found");
        {
            init = {
                ledger_borrow;
                ledger_collateral;
            };
            variables = {
                interest = 20;
            };
        };
    };

    // Modify request
    public type ModifyRequest = {
        interest : Nat;
    };

    // How does the modify request change memory
    public func modifyRequestMut(mem : Mem, t : ModifyRequest) : Result.Result<(), Text> {
        mem.variables.interest := t.interest;
        #ok();
    };

    // Public shared state
    public type Shared = {
        init : {
            ledger_borrow : Principal;
            ledger_collateral : Principal;
        };
        variables : {
            interest : Nat;
        };
        internals : {};
    };

    // Convert memory to shared
    public func toShared(t : Mem) : Shared {
        {
            init = t.init;
            variables = {
                interest = t.variables.interest;
            };
            internals = {};
        };
    };

    public func sources(t : Mem) : Node.PortsDescription {
        [(t.init.ledger_collateral, "Collateral"), (t.init.ledger_borrow, "Repayment")];
    };

    public func destinations(t : Mem) : Node.PortsDescription {
        [(t.init.ledger_borrow, ""), (t.init.ledger_collateral, "Collateral")];
    };



};
