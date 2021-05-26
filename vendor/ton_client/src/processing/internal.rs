use super::fetching::fetch_account;
use crate::abi::{Abi, ParamsOfDecodeMessage};
use crate::client::ClientContext;
use crate::error::{ClientError, ClientResult};
use crate::processing::Error;
use crate::tvm::{AccountForExecutor, ExecutionOptions, ParamsOfRunExecutor};
use std::sync::Arc;
use ton_block::MsgAddressInt;
use ton_sdk::{Block, MessageId};

/// Increments `retries` and returns `true` if `retries` hasn't reached `limit`.
pub(crate) fn can_retry_more(retries: u8, limit: i8) -> bool {
    limit < 0 || retries < limit as u8
}

pub fn can_retry_network_error(context: &Arc<ClientContext>, start: u64) -> bool {
    context.env.now_ms() < start + context.config.network.max_reconnect_timeout as u64
}

pub(crate) fn can_retry_expired_message(context: &Arc<ClientContext>, retries: u8) -> bool {
    can_retry_more(retries, context.config.network.message_retries_count)
}

pub fn find_transactions(
    block: &Block,
    message_id: &str,
    shard_block_id: &String,
) -> ClientResult<Vec<String>> {
    let mut ids = Vec::new();
    let msg_id: MessageId = message_id.into();
    for msg_descr in &block.in_msg_descr {
        if Some(&msg_id) == msg_descr.msg_id.as_ref() {
            ids.push(
                msg_descr
                    .transaction_id
                    .as_ref()
                    .ok_or(Error::invalid_block_received(
                        "No field `transaction_id` in block's `in_msg_descr`.",
                        message_id,
                        shard_block_id,
                    ))?
                    .to_string(),
            );
        }
    }
    Ok(ids)
}

pub(crate) async fn get_message_expiration_time(
    context: Arc<ClientContext>,
    abi: Option<&Abi>,
    message: &str,
) -> ClientResult<Option<u64>> {
    let header = match abi {
        Some(abi) => crate::abi::decode_message(
            context.clone(),
            ParamsOfDecodeMessage {
                abi: abi.clone(),
                message: message.to_string(),
            },
        )
        .await
        .map(|x| x.header)
        .unwrap_or_default(),
        None => None,
    };
    let time = header
        .as_ref()
        .map_or(None, |x| x.expire)
        .map(|x| x as u64 * 1000);
    Ok(time)
}

async fn get_local_error(
    context: Arc<ClientContext>,
    address: &MsgAddressInt,
    message: String,
    time: u32,
) -> ClientResult<()> {
    let account = fetch_account(context.clone(), address, "boc").await?;

    let boc = account["boc"]
        .as_str()
        .ok_or(Error::invalid_data("Account doesn't contain 'boc'"))?
        .to_owned();

    crate::tvm::run_executor(
        context,
        ParamsOfRunExecutor {
            abi: None,
            account: AccountForExecutor::Account {
                boc,
                unlimited_balance: None,
            },
            execution_options: Some(ExecutionOptions {
                block_time: Some(time),
                ..Default::default()
            }),
            message,
            ..Default::default()
        },
    )
    .await
    .map(|_| ())
}

pub(crate) async fn resolve_error(
    context: Arc<ClientContext>,
    address: &MsgAddressInt,
    message: String,
    mut original_error: ClientError,
    time: u32,
) -> ClientResult<()> {
    let result = get_local_error(context, address, message, time).await;

    match result {
        Err(err) => {
            original_error.message = format!(
                "{}. Possible reason: {}",
                original_error.message.trim_end_matches("."),
                err.message
            );
            original_error.data["local_error"] =
                serde_json::to_value(err).map_err(crate::client::Error::cannot_serialize_result)?;
            Err(original_error)
        }
        Ok(_) => {
            original_error.message = format!(
                "{}. Local contract call emulation was successful. Possible reason: message has not been delivered.",
                original_error.message.trim_end_matches("."),
            );
            Err(original_error)
        }
    }
}
