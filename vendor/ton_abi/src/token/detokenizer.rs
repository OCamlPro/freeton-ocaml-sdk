/*
* Copyright 2018-2020 TON DEV SOLUTIONS LTD.
*
* Licensed under the SOFTWARE EVALUATION License (the "License"); you may not use
* this file except in compliance with the License.
*
* Unless required by applicable law or agreed to in writing, software
* distributed under the License is distributed on an "AS IS" BASIS,
* WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
* See the License for the specific TON DEV software governing permissions and
* limitations under the License.
*/

use crate::{
    error::AbiError, param::Param, param_type::ParamType, token::{Token, TokenValue}
};

use num_bigint::{BigInt, BigUint};
use serde::ser::{Serialize, Serializer, SerializeMap};
use std::collections::HashMap;
use ton_types::{Cell, error, fail, Result, serialize_tree_of_cells};

pub struct Detokenizer;

impl Detokenizer {
    pub fn detokenize(params: &[Param], tokens: &[Token]) -> Result<String> {
        Ok(
            serde_json::to_string(
                &Self::detokenize_to_json_value(params, tokens)?
            )?
        )
    }

    pub fn detokenize_to_json_value(params: &[Param], tokens: &[Token]) -> Result<serde_json::Value> {
        if params.len() != tokens.len() {
            fail!(AbiError::WrongParametersCount {
                expected: params.len(),
                provided: tokens.len()
            });
        }

        if !Token::types_check(tokens, params) {
             fail!(AbiError::WrongParameterType);
        }

        Ok(serde_json::to_value(&FunctionParams{params: tokens})?)
    }

    pub fn detokenize_optional(tokens: &HashMap<String, TokenValue>) -> Result<String> {
        Ok(
            serde_json::to_string(
                &Self::detokenize_optional_to_json_value(tokens)?
            )?
        )
    }

    pub fn detokenize_optional_to_json_value(tokens: &HashMap<String, TokenValue>) -> Result<serde_json::Value> {
        serde_json::to_value(&tokens).map_err(|err| err.into())
    }
}

pub struct FunctionParams<'a> {
    params: &'a [Token],
}

impl<'a> Serialize for FunctionParams<'a> {
        fn serialize<S>(&self, serializer: S) -> std::result::Result<S::Ok, S::Error>
    where
        S: Serializer,
    {
        let mut map = serializer.serialize_map(Some(self.params.len()))?;

        for token in self.params {
                map.serialize_entry(&token.name, &token.value)?;
            }

        map.end()
    }
}

impl Token {
    pub fn detokenize_big_int<S>(number: &BigInt, serializer: S) -> std::result::Result<S::Ok, S::Error>
    where
        S: Serializer,
    {
        serializer.serialize_str(&number.to_str_radix(10))
    }

    pub fn detokenize_big_uint<S>(
        number: &BigUint,
        size: usize,
        serializer: S,
    ) -> std::result::Result<S::Ok, S::Error>
    where
        S: Serializer,
    {
        let uint_str = if size == 256 {
            format!("0x{:0>64}", number.to_str_radix(16))
        } else {
            number.to_str_radix(10)
        };
        serializer.serialize_str(&uint_str)
    }

    pub fn detokenize_hashmap<S>(_key_type: &ParamType, values: &HashMap<String, TokenValue>, serializer: S) -> std::result::Result<S::Ok, S::Error>
    where
        S: Serializer,
    {
        let mut map = serializer.serialize_map(Some(values.len()))?;
        for (k, v) in values {
            map.serialize_entry(k, v)?;
        }
        map.end()
    }

    pub fn detokenize_cell<S>(cell: &Cell, serializer: S) -> std::result::Result<S::Ok, S::Error>
    where
        S: Serializer,
    {
        let mut data = vec![];
        serialize_tree_of_cells(cell, &mut data)
            .map_err(|err| serde::ser::Error::custom(err.to_string()))?;

        let data = base64::encode(&data);
        serializer.serialize_str(&data)
    }

    pub fn detokenize_bytes<S>(arr: &Vec<u8>, serializer: S) -> std::result::Result<S::Ok, S::Error>
    where
        S: Serializer,
    {
        let data = hex::encode(arr);
        serializer.serialize_str(&data)
    }

    pub fn detokenize_public_key<S>(value: &Option<ed25519_dalek::PublicKey>, serializer: S) -> std::result::Result<S::Ok, S::Error>
    where
        S: Serializer,
    {
        if let Some(key) = value {
            Self::detokenize_bytes(&key.to_bytes().to_vec(), serializer)
        } else {
            serializer.serialize_str("")
        }
    }
}

impl Serialize for TokenValue {
    fn serialize<S>(&self, serializer: S) -> std::result::Result<S::Ok, S::Error>
    where
        S: Serializer,
    {
        match self {
            TokenValue::Uint(uint) => {
                Token::detokenize_big_uint(&uint.number, uint.size, serializer)
            }
            TokenValue::Int(int) => Token::detokenize_big_int(&int.number, serializer),
            TokenValue::Bool(b) => serializer.serialize_bool(b.clone()),
            TokenValue::Tuple(tokens) => {
                FunctionParams {params: tokens}.serialize(serializer)
            },
            TokenValue::Array(ref tokens) => tokens.serialize(serializer),
            TokenValue::FixedArray(ref tokens) => tokens.serialize(serializer),
            TokenValue::Cell(ref cell) => Token::detokenize_cell(cell, serializer),
            TokenValue::Map(key_type, ref map) => Token::detokenize_hashmap(key_type, map, serializer),
            TokenValue::Address(ref address) => serializer.serialize_str(&address.to_string()),
            TokenValue::Bytes(ref arr) => Token::detokenize_bytes(arr, serializer),
            TokenValue::FixedBytes(ref arr) => Token::detokenize_bytes(arr, serializer),
            TokenValue::Gram(gram) => Token::detokenize_big_int(&gram.value(), serializer),
            TokenValue::Time(time) => {
                Token::detokenize_big_uint(&BigUint::from(*time), 64, serializer)
            }
            TokenValue::Expire(expire) => {
                Token::detokenize_big_uint(&BigUint::from(*expire), 32, serializer)
            }
            TokenValue::PublicKey(key) => Token::detokenize_public_key(&key, serializer),
        }
    }
}
