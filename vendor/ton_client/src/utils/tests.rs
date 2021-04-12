use crate::{boc::tests::ACCOUNT, json_interface::modules::UtilsModule};
use crate::tests::TestClient;
use super::*;
use api_info::ApiModule;

#[tokio::test(core_threads = 2)]
async fn test_utils() {
    TestClient::init_log();
    let client = TestClient::new();
    let convert_address = client.wrap(
        convert_address,
        UtilsModule::api(),
        super::conversion::convert_address_api(),
    );

    let account_id = "fcb91a3a3816d0f7b8c2c76108b8a9bc5a6b7a55bd79f8ab101c52db29232260";
    let hex = "-1:fcb91a3a3816d0f7b8c2c76108b8a9bc5a6b7a55bd79f8ab101c52db29232260";
    let hex_workchain0 = "0:fcb91a3a3816d0f7b8c2c76108b8a9bc5a6b7a55bd79f8ab101c52db29232260";
    let base64 = "Uf/8uRo6OBbQ97jCx2EIuKm8Wmt6Vb15+KsQHFLbKSMiYG+9";
    let base64url = "kf_8uRo6OBbQ97jCx2EIuKm8Wmt6Vb15-KsQHFLbKSMiYIny";

    let converted = convert_address
        .call(ParamsOfConvertAddress {
            address: account_id.into(),
            output_format: AddressStringFormat::Hex {},
        })
        .unwrap();
    assert_eq!(converted.address, hex_workchain0);

    let converted = convert_address
        .call(ParamsOfConvertAddress {
            address: account_id.into(),
            output_format: AddressStringFormat::AccountId {},
        })
        .unwrap();
    assert_eq!(converted.address, account_id);

    let converted = convert_address
        .call(ParamsOfConvertAddress {
            address: hex.into(),
            output_format: AddressStringFormat::Base64 {
                bounce: false,
                test: false,
                url: false,
            },
        })
        .unwrap();
    assert_eq!(converted.address, base64);

    let converted = convert_address
        .call(ParamsOfConvertAddress {
            address: base64.into(),
            output_format: AddressStringFormat::Base64 {
                bounce: true,
                test: true,
                url: true,
            },
        })
        .unwrap();
    assert_eq!(converted.address, base64url);

    let converted = convert_address
        .call(ParamsOfConvertAddress {
            address: base64url.into(),
            output_format: AddressStringFormat::Hex {},
        })
        .unwrap();
    assert_eq!(converted.address, hex);
}

#[tokio::test(core_threads = 2)]
async fn test_calc_storage_fee() {
    let client = TestClient::new();

    let result: ResultOfCalcStorageFee = client.request_async(
        "utils.calc_storage_fee",
        ParamsOfCalcStorageFee {
            account: String::from(ACCOUNT),
            period: 1000,
        }
    ).await.unwrap();

    assert_eq!(result.fee, "330");
}
