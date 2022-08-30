# 1、合约介绍
    合约主要定义一个token，token持有者可以按照1:1兑换XUSDT
# 2、环境准备
## 1.1 启动本地节点
    1、下载最新版本的starcoin安装包，把解压后的目录配置到环境变量里
    下载地址：
    https://github.com/starcoinorg/starcoin/releases
    2、打开一个控制台，启动节点
    starcoin -n dev
    3、打开一个新的控制台，启动交互式环境
    starcoin  -n dev  console
## 1.2 账号准备
    新建两个账号一个用来部署合约，另一个用来和合约兑换XUSDT
    account create -p 123456
    这里生成账号（用于部署合约）：
    0x1641b99d5c1a94bfcbb538fc9a89c6d8
    通过控制台给账号充钱
    dev get-coin 0x1641b99d5c1a94bfcbb538fc9a89c6d8 -v 2000STC
    用同样的方法生成另一个账号并且充钱（用于兑换XUSDT）：0xa80f1454527a8c8b455b6eb306b0e327
# 3、合约分析
    代码共包含两个合约：MyToken和XUSDT，其中MyToken合约为自定义的token，XUSDT合约为了配合兑换定义的token合约，
MyToken合约的基本信息：
```
#定义token
struct MyToken has copy, drop, store {
        
    }
#定义token的基本信息
struct MyTokenExtInfo has key {
            name:vector<u8>,
            symbol:vector<u8>,
            description:vector<u8>,
            logo:vector<u8>
    }
#定义取款的capability，在兑换时可以不需要签名从账户里把#token取出来
struct WithDrawCap has key{
            withdraw_cap :WithdrawCapability
      }
# 定义兑换成功后的事件
struct SwapEvent has drop ,store{
         sender:address,
         amount:u128
      }
# 事件统一存储在此资源下
struct EventStore has key{
         swap_events: Event::EventHandle<SwapEvent>,
     }
```
MyToken合约中的函数:
```
#初始化函数，完成MyToken的注册
public(script) fun init(admin: signer,name:vector<u8>,symbol:vector<u8>,description:vector<u8>,logo:vector<u8>)  {
         # 从签名中获取管理员的账户地址
         let admin_address = Signer::address_of(&admin);
         # 判断管理员地址是否和部署合约的账号是否一致
         assert!(admin_address== @MyTokenAddr,ERR_NOT_ADMIN);
         # 按照starcoin framework的token标准中注册自定义的token
         Token::register_token<MyToken>(&admin, 8);
         # 允许管理员账号接受自定义token
         Account::do_accept_token<MyToken>(&admin);
         #从管理员账号里取出取款的capability
         let withdraw_cap = Account::extract_withdraw_capability(&admin);
         # 把取款的capability的以资源的形式存入用户的账户下
         move_to(&admin,WithDrawCap{
            withdraw_cap:withdraw_cap
         });
         #把token的基本信息存入到账号下
         move_to(&admin, MyTokenExtInfo{
                name:name,
                symbol:symbol,
                description:description,
                logo:logo
        });
        # 初始化事件
        move_to(&admin,EventStore{
           swap_events:Event::new_event_handle<SwapEvent>(&admin),
        })
     }
```
MyToken的铸造
```
 public(script) fun mint(account: signer,receiver:address, amount: u128) {
        let admin_address = Signer::address_of(&account);
        assert!(admin_address== @MyTokenAddr,ERR_NOT_ADMIN);
        #使用Token标准的mint函数铸造MyToken
        let token = Token::mint<MyToken>(&account, amount);
        #把铸造的token存储到接收者的账户下
        Account::deposit<MyToken>(receiver, token);
     }
```
MyToken和XUSDT兑换
```
 fun swap_internal(account: signer,amount:u128) acquires WithDrawCap,EventStore{
        let account_address = Signer::address_of(&account);
        # 从合约里取出XUSDT的余额
        let xusdt_balance = Account::balance<XUSDT>(@MyTokenAddr);
        assert!(xusdt_balance >= amount, ERR_INSUFFICIENT_BALANCE);
        #从兑换人的账号里取出MyToken
        let token = Account::withdraw<MyToken>(&account,amount);
        #把兑换人的MyToken存入合约拥有者账号下
        Account::deposit<MyToken>(@MyTokenAddr, token);
        #获取管理员的取款capability
        let withdraw_ability = borrow_global<WithDrawCap>(@MyTokenAddr);
        #从管理员的账户下取出对应的数量的XUSDT
        let xusdt= Account::withdraw_with_capability<XUSDT>(& withdraw_ability.withdraw_cap,amount);
        #把XUSDT存入到兑换人的账户里
        Account::deposit<XUSDT>(account_address, xusdt);
        #事件记录
        let event_store = borrow_global_mut<EventStore>(@MyTokenAddr);
        Event::emit_event<SwapEvent>(&mut event_store.swap_events, SwapEvent {
            sender:account_address,
            amount:amount,
        });
     }
```
# 4、部署调用合约
## 1、修改toml文件 
```
[addresses]
StarcoinFramework = "0x1"
MyTokenAddr = "0x1641b99d5c1a94bfcbb538fc9a89c6d8"
XUSDTAddr ="0x1641b99d5c1a94bfcbb538fc9a89c6d8"
```
## 2、合约编译
```
mpm release
```
## 3、解锁部署账户(starcoin控制台)
```
account unlock 0x1641b99d5c1a94bfcbb538fc9a89c6d8 -p 123456
```
## 4、部署合约（starcoin控制台）
```
dev deploy /合约路径/release/mytToken.v0.0.0.blob -s 0x1641b99d5c1a94bfcbb538fc9a89c6d8
```
## 5、合约交互
### 5.1 XUSDT铸造
```
初始化XUSDT
account execute-function --function 0x1641b99d5c1a94bfcbb538fc9a89c6d8::XUSDT::init -s 0x1641b99d5c1a94bfcbb538fc9a89c6d8 -b
向合约账户里存入2200个XUSDT
account execute-function --function 0x1641b99d5c1a94bfcbb538fc9a89c6d8::XUSDT::mint -s 0x1641b99d5c1a94bfcbb538fc9a89c6d8 --arg  0x1641b99d5c1a94bfcbb538fc9a89c6d8 --arg 2200u128  -b
```
### 5.2 MyToken铸造和兑换
```
初始化MyToken
account execute-function --function 0x1641b99d5c1a94bfcbb538fc9a89c6d8::MyToken::init -s 0x1641b99d5c1a94bfcbb
538fc9a89c6d8  --arg b"mytoken" --arg b"mytoken" --arg b"my first token" --arg b"https://gateway.pinata.cloud/ipfs/QmW95h6ATWdUk8eBH2tBBNRtW7zNtxcXYXg2Zb8w5An2mH"  -b
向兑换者发放MyToken
account execute-function --function 0x1641b99d5c1a94bfcbb538fc9a89c6d8::MyToken::mint -s 0x1641b99d5c1a94bfcbb538fc9a89c6d8 --arg  0xa80f1454527a8c8b455b6eb306b0e327 --arg 2200u128  -b
兑换者发起兑换
account execute-function --function 0x1641b99d5c1a94bfcbb538fc9a89c6d8::MyToken::swap -s 0xa80f1454527a8c8b455b6eb306b0e327    --arg 100u128  -b
```