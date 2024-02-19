import * as Collapsible from "@radix-ui/react-collapsible";
import { Typography } from "design-system";
import Image from "next/image";

import { api } from "~/utils/api";

import NftTransferStatus from "./NftTransferStatus";

interface NftTransferItemContentProps {
  contractAddress: string;
  displayedArrivalAddress: string;
  open: boolean;
  status:
    | "deposit_initiated_l1"
    | "deposit_initiated_l2"
    | "error"
    | "withdraw_completed_l1"
    | "withdraw_completed_l2";
  tokenIds: Array<string>;
}

export default function NftTransferItemContent({
  contractAddress,
  displayedArrivalAddress,
  open,
  status,
  tokenIds,
}: NftTransferItemContentProps) {
  const { data: nfts } = api.l1Nfts.getNftMetadataBatch.useQuery(
    {
      contractAddress,
      tokenIds,
    },
    {
      enabled: open,
    }
  );

  if (nfts === undefined) {
    return <></>;
  }

  return (
    <Collapsible.Content asChild>
      <div className="flex rounded-b-2xl border-x border-b border-asteroid-grey-100 bg-white px-6 py-8 dark:border-space-blue-800 dark:bg-space-blue-900">
        <div className="mr-4 w-0.5 rounded-full bg-asteroid-grey-100 dark:bg-space-blue-800" />
        <div className="flex w-full flex-col gap-4 ">
          {nfts.map((nft) => {
            return (
              <div>
                <div className="grid grid-cols-[1fr_1fr_1fr_1fr_2.25rem] place-items-start items-center">
                  <div className="flex items-center gap-4">
                    {nft.image !== undefined ? (
                      <Image
                        alt="nft"
                        className="flex-shrink-0 rounded-md"
                        height={52}
                        src={nft.image}
                        width={52}
                      />
                    ) : (
                      <>
                        <Image
                          alt="empty Nft image"
                          className="hidden aspect-square rounded-lg object-cover dark:block"
                          height={52}
                          src={`/medias/dark/empty_nft.png`}
                          width={52}
                        />
                        <Image
                          alt="empty Nft image"
                          className="aspect-square rounded-lg object-cover dark:hidden"
                          height={52}
                          src={`/medias/empty_nft.png`}
                          width={52}
                        />
                      </>
                    )}
                    <div className="text-left">
                      <Typography component="p" variant="body_text_14">
                        {nft.collectionName}
                      </Typography>
                      <Typography component="p" variant="body_text_bold_14">
                        {nft.tokenName}
                      </Typography>
                    </div>
                  </div>
                  <NftTransferStatus status={status} />

                  <div className="flex items-center gap-2">
                    <Typography component="p" variant="button_text_s">
                      {displayedArrivalAddress}
                    </Typography>
                  </div>
                </div>
              </div>
            );
          })}
        </div>
      </div>
    </Collapsible.Content>
  );
}