import { Col } from 'web/components/layout/col'
import { LoadingIndicator } from 'web/components/widgets/loading-indicator'
import clsx from 'clsx'
import Link from 'next/link'
import { useAPIGetter } from 'web/hooks/use-api-getter'
import { FeedContractCard } from 'web/components/contract/feed-contract-card'
import { VisibilityObserver } from 'web/components/widgets/visibility-observer'
import { usePersistentInMemoryState } from 'web/hooks/use-persistent-in-memory-state'
import { useEffect, useState } from 'react'
import { APIResponse } from 'common/api/schema'
import { uniqBy } from 'lodash'
import { ScoredFeedRepost } from 'web/components/feed/scored-feed-repost-item'
import { useUser } from 'web/hooks/use-user'
import { Contract } from 'common/contract'
import { Repost } from 'common/repost'
import { ContractComment } from 'common/comment'
import { Bet } from 'common/bet'
import { User } from 'common/user'
import { Row } from 'web/components/layout/row'

export function ScoredFeed(props: { userId: string; className?: string }) {
  const { userId, className } = props
  const user = useUser()
  const [offset, setOffset] = usePersistentInMemoryState(
    0,
    `feed-offset-${userId}`
  )
  const limit = 5
  const [feedData, setFeedData] = usePersistentInMemoryState(
    {
      contracts: [],
      comments: [],
      idsToReason: {},
      bets: [],
      reposts: [],
    } as APIResponse<'get-feed'>,
    `feed-data-${userId}`
  )
  const ignoreContractIds = feedData.contracts.map((c) => c.id)
  const { data, error } = useAPIGetter(
    'get-feed',
    {
      userId,
      offset,
      limit,
      ignoreContractIds,
    },
    ['ignoreContractIds']
  )

  if (error) {
    console.error(error.message)
  }

  useEffect(() => {
    if (!data) return
    setFeedData({
      contracts: uniqBy(feedData.contracts.concat(data.contracts), 'id'),
      comments: uniqBy(feedData.comments.concat(data.comments), 'id'),
      idsToReason: { ...feedData.idsToReason, ...data.idsToReason },
      bets: uniqBy(feedData.bets.concat(data.bets), 'id'),
      reposts: uniqBy(feedData.reposts.concat(data.reposts), 'id'),
    })
  }, [data])
  const { contracts, reposts, comments, bets, idsToReason } = feedData

  if (data === undefined && contracts.length === 0)
    return <LoadingIndicator className={className} />

  return (
    <Col className={clsx('relative w-full gap-4', className)}>
      {contracts.map((contract) => {
        const repost = reposts.find((r) => r.contract_id === contract.id)
        const comment = comments.find((c) => c.contractId === contract.id)
        const bet = bets.find((b) => b.contractId === contract.id)
        return (
          <FeedCard
            key={contract.id + comment?.id}
            contract={contract}
            repost={repost}
            comment={comment}
            bet={bet}
            user={user}
            reason={idsToReason?.[contract.id]}
          />
        )
      })}
      <div className="relative">
        <VisibilityObserver
          className="pointer-events-none absolute bottom-0 h-screen w-full select-none"
          onVisibilityUpdated={(visible) =>
            visible && setOffset(offset + limit)
          }
        />
      </div>
      {contracts.length === 0 && (
        <div className="text-ink-1000 m-4 flex w-full flex-col items-center justify-center">
          <div>Congratulations!</div>
          <div>You've reached the end of the feed.</div>
          <div>You are free.</div>
          <br />
          <Link
            href="/browse?s=newest&f=open"
            className="text-primary-700 hover:underline"
          >
            Browse new questions
          </Link>
          <Link href="/create" className="text-primary-700 hover:underline">
            Create a question
          </Link>
        </div>
      )}
    </Col>
  )
}

const FeedCard = (props: {
  contract: Contract
  repost: Repost | undefined
  comment: ContractComment | undefined
  bet: Bet | undefined
  user: User | undefined | null
  reason?: string
}) => {
  const { contract, reason, user, repost, comment, bet } = props
  const [hidden, setHidden] = useState(false)
  return hidden ? (
    <Col
      className={clsx(
        'bg-canvas-0 border-canvas-0 rounded-xl border drop-shadow-md'
      )}
    >
      <Row className={'text-ink-400 mb-4 px-4 pt-3 text-sm'}>
        <i>Market hidden</i>
      </Row>
    </Col>
  ) : repost && comment ? (
    <ScoredFeedRepost
      contract={contract}
      comment={comment}
      repost={repost}
      trackingLocation={'feed'}
      bet={bet}
      user={user}
      hide={() => setHidden(true)}
    />
  ) : (
    <FeedContractCard
      contract={contract}
      key={contract.id}
      hide={() => setHidden(true)}
      endpointReason={reason}
    />
  )
}