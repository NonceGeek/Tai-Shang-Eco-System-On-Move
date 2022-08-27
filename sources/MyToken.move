module MyTokenAddr::MyToken {
     use StarcoinFramework::Token;
     use StarcoinFramework::Account::{Self,WithdrawCapability};
     use StarcoinFramework::Signer;
     use StarcoinFramework::Event;
     use XUSDTAddr::XUSDT::XUSDT ;
     struct MyToken has copy, drop, store {
        
      }
      struct WithDrawCap has key{
            withdraw_cap :WithdrawCapability
      }
      struct MyTokenExtInfo has key {
            name:vector<u8>,
            symbol:vector<u8>,
            description:vector<u8>,
            logo:vector<u8>
      }

      struct SwapEvent has drop ,store{
         sender:address,
         amount:u128
      }
     struct EventStore has key{
         swap_events: Event::EventHandle<SwapEvent>,
     }

     const ERR_NOT_ADMIN:u64 = 1;
     const ERR_INSUFFICIENT_BALANCE:u64 = 2;

     public(script) fun init(admin: signer,name:vector<u8>,symbol:vector<u8>,description:vector<u8>,logo:vector<u8>)  {
         let admin_address = Signer::address_of(&admin);
         // Event::publish_generator(&admin);
         assert!(admin_address== @MyTokenAddr,ERR_NOT_ADMIN);
         Token::register_token<MyToken>(&admin, 8);
         Account::do_accept_token<MyToken>(&admin);
         let withdraw_cap = Account::extract_withdraw_capability(&admin);
         move_to(&admin,WithDrawCap{
            withdraw_cap:withdraw_cap
         });
         move_to(&admin, MyTokenExtInfo{
                name:name,
                symbol:symbol,
                description:description,
                logo:logo
        });
        move_to(&admin,EventStore{
           swap_events:Event::new_event_handle<SwapEvent>(&admin),
        })
     }

     public(script) fun mint(account: signer,receiver:address, amount: u128) {
        let admin_address = Signer::address_of(&account);
        assert!(admin_address== @MyTokenAddr,ERR_NOT_ADMIN);
         if(!Account::is_accepts_token<MyToken>(admin_address)){
            Account::do_accept_token<MyToken>(&account);
        };
        let token = Token::mint<MyToken>(&account, amount);
        Account::deposit<MyToken>(receiver, token);
     }
 
     fun swap_internal(account: signer,amount:u128) acquires WithDrawCap,EventStore{
        let account_address = Signer::address_of(&account);
        let xusdt_balance = Account::balance<XUSDT>(@MyTokenAddr);
        assert!(xusdt_balance >= amount, ERR_INSUFFICIENT_BALANCE);
        let token = Account::withdraw<MyToken>(&account,amount);
        
        Account::deposit<MyToken>(@MyTokenAddr, token);
      
        let withdraw_ability = borrow_global<WithDrawCap>(@MyTokenAddr);
        let xusdt= Account::withdraw_with_capability<XUSDT>(& withdraw_ability.withdraw_cap,amount);
        Account::deposit<XUSDT>(account_address, xusdt);
        let event_store = borrow_global_mut<EventStore>(@MyTokenAddr);
        Event::emit_event<SwapEvent>(&mut event_store.swap_events, SwapEvent {
            sender:account_address,
            amount:amount,
        });
     }

     public(script)  fun swap(account: signer,amount:u128)   acquires WithDrawCap,EventStore{
        swap_internal(account,amount);
     }

 
}
