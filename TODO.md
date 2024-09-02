
icrc55_register_nodefactory(principal)

---

icrc55_get_nodefactory_meta() 
    - name
    - description
    - icon
    - governed_by (dao, self auth, canister, blackhole)
    - supported ledgers (principals)
    - princing : Text

icrc55_get_node({subaccount:...})
    ICRC interface for getting vector node input ports, types, outputs and destinations, also destinations should be convertable to vector ids, also we should be able to query vector from one of its sources and not just the id
    returns the vector info
    and a list of destination addresses

icrc55_create_node(A)

icrc55_create_node_get_fee(A)
- currency, amount 