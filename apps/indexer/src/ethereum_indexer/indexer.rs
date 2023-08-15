use anyhow::{Result, anyhow};
use ethers::types::{Address, BlockNumber};

use crate::storage::store::{RequestStore, EventStore};
use crate::config::ChainConfig;

use super::client::EthereumClient;
use super::events;

use tokio::time::{self, Duration};
use std::sync::Arc;
use std::str::FromStr;

///
pub struct EthereumIndexer {
    client: EthereumClient,
    config: ChainConfig,
}

impl EthereumIndexer {
    ///
    pub async fn new(config: ChainConfig) -> Result<EthereumIndexer> {
        let client = EthereumClient::new(
            &config.rpc_url,
            &config.address,
            &config.account_private_key,
        ).await?;

        Ok(EthereumIndexer {
            client,
            config,
        })
    }

    ///
    pub async fn start<T: RequestStore + EventStore>(&self, store: Arc<T>) -> Result<()> {

        let mut from_u64: u64 = match BlockNumber::from_str(&self.config.from_block).expect("Invalid from_block value") {
            BlockNumber::Earliest => 0,
            BlockNumber::Number(x) => x.try_into().expect("Not a valid u64 (from)"),
            _ => anyhow::bail!("Invalid block number (from_block)"),
        };

        let mut to_block_was_latest = false;
        let mut to_u64: u64 = match &self.config.to_block {
            Some(b) => {
                match BlockNumber::from_str(b).expect("Invalid to_block value") {
                    BlockNumber::Latest => {
                        to_block_was_latest = true;
                        self.client.get_block_number().await
                    },
                    BlockNumber::Number(x) => x.0[0],
                    _ => anyhow::bail!("Invalid block number (to_block)"),
                }
            },
            None => self.client.get_block_number().await
        };

        loop {
            // TODO: verify if the block is not already fetched and processed.

            // Here, we use fetch_logs as Starklane for now doesn't have
            // a lot's of events to monitor.
            match self.client.fetch_logs(from_u64, to_u64).await {
                Ok(logs) => {
                    let n_logs = logs.len();
                    log::info!("\nEth fetching blocks {} - {} ({} logs)", from_u64, to_u64, n_logs);

                    for l in logs {
                        match events::get_store_data(l)? {
                            (Some(r), Some(e)) => {
                                store.insert_req(r).await?;
                                store.insert_event(e.clone()).await?;

                                if e.block_number > from_u64 {
                                    from_u64 = e.block_number;
                                }
                            },
                            _ => log::warn!("Event emitted by Starklane possibly is not handled"),
                        };
                    }

                    if n_logs > 0 {
                        // To ensure those blocks are not fetched anymore,
                        // as the get_logs range includes the from_block value.
                        from_u64 += 1;

                        // We want to continue polling the head of the chain if the
                        // to_block is set to "latest" in the config.
                        if to_block_was_latest {
                            to_u64 = self.client.get_block_number().await;
                            if from_u64 > to_u64 {
                                // More consistent to always have from and to equal,
                                // or to > from.
                                to_u64 = from_u64;
                            }
                        } else {
                            // We stop at the block number in the configuration.
                            if from_u64 > to_u64 {
                                return Ok(())
                            }
                        }
                    }
                },
                Err(e) => log::error!("Error at getting eth logs {:?}", e)
            };

            time::sleep(Duration::from_secs(self.config.fetch_interval)).await;
        }
    }
}
