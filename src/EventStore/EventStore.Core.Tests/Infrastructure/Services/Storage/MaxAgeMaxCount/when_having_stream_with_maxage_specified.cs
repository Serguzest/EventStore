﻿// Copyright (c) 2012, Event Store LLP
// All rights reserved.
//  
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions are
// met:
//  
// Redistributions of source code must retain the above copyright notice,
// this list of conditions and the following disclaimer.
// Redistributions in binary form must reproduce the above copyright
// notice, this list of conditions and the following disclaimer in the
// documentation and/or other materials provided with the distribution.
// Neither the name of the Event Store LLP nor the names of its
// contributors may be used to endorse or promote products derived from
// this software without specific prior written permission
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
// "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
// LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
// A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
// HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
// SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
// LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
// DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
// THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
// (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
// OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
//  
using System;
using System.Text;
using EventStore.Core.Data;
using EventStore.Core.Services;
using EventStore.Core.Services.Storage.ReaderIndex;
using EventStore.Core.TransactionLog.LogRecords;
using NUnit.Framework;

namespace EventStore.Core.Tests.Infrastructure.Services.Storage.MaxAgeMaxCount
{
    [TestFixture]
    public class when_having_stream_with_maxage_specified: ReadIndexTestScenario
    {
        private EventRecord _r1;
        private EventRecord _r2;
        private EventRecord _r3;
        private EventRecord _r4;
        private EventRecord _r5;
        private EventRecord _r6;

        protected override void WriteTestScenario()
        {
            var now = DateTime.UtcNow;

            long curPos;
            const string metadata = @"{""$maxAge"":10}";

            var streamCreated = new PrepareLogRecord(0,
                                                     Guid.NewGuid(),
                                                     Guid.NewGuid(),
                                                     0,
                                                     0,
                                                     "ES",
                                                     ExpectedVersion.NoStream,
                                                     now.AddSeconds(-100),
                                                     PrepareFlags.Data | PrepareFlags.TransactionBegin | PrepareFlags.TransactionEnd,
                                                     SystemEventTypes.StreamCreated,
                                                     LogRecord.NoData,
                                                     Encoding.UTF8.GetBytes(metadata));
            _r1 = new EventRecord(0, streamCreated);
            Writer.Write(streamCreated, out curPos);
            Writer.Write(LogRecord.Commit(curPos, Guid.NewGuid(), 0, 0), out curPos);

            _r2 = WriteSingleEvent("ES", 1, "bla1", now.AddSeconds(-50));
            _r3 = WriteSingleEvent("ES", 2, "bla1", now.AddSeconds(-20));
            _r4 = WriteSingleEvent("ES", 3, "bla1", now.AddSeconds(-11));
            _r5 = WriteSingleEvent("ES", 4, "bla1", now.AddSeconds(-5));
            _r6 = WriteSingleEvent("ES", 5, "bla1", now.AddSeconds(-1));
        }

        [Test]
        public void single_event_read_doesnt_return_stream_created_event()
        {
            EventRecord record;
            Assert.AreEqual(SingleReadResult.NotFound, ReadIndex.ReadEvent("ES", 0, out record));
            Assert.IsNull(record);
        }

        [Test]
        public void single_event_read_doesnt_return_expired_events_and_returns_all_actual_ones()
        {
            EventRecord record;
            Assert.AreEqual(SingleReadResult.NotFound, ReadIndex.ReadEvent("ES", 0, out record));
            Assert.IsNull(record);
            Assert.AreEqual(SingleReadResult.NotFound, ReadIndex.ReadEvent("ES", 1, out record));
            Assert.IsNull(record);
            Assert.AreEqual(SingleReadResult.NotFound, ReadIndex.ReadEvent("ES", 2, out record));
            Assert.IsNull(record);
            Assert.AreEqual(SingleReadResult.NotFound, ReadIndex.ReadEvent("ES", 3, out record));
            Assert.IsNull(record);

            Assert.AreEqual(SingleReadResult.Success, ReadIndex.ReadEvent("ES", 4, out record));
            Assert.AreEqual(_r5, record);
            Assert.AreEqual(SingleReadResult.Success, ReadIndex.ReadEvent("ES", 5, out record));
            Assert.AreEqual(_r6, record);
        }

        [Test]
        public void forward_range_read_doesnt_return_expired_records()
        {
            EventRecord[] records;
            Assert.AreEqual(RangeReadResult.Success, ReadIndex.ReadStreamEventsForward("ES", 0, 100, out records));
            Assert.AreEqual(2, records.Length);
            Assert.AreEqual(_r5, records[0]);
            Assert.AreEqual(_r6, records[1]);
        }

        [Test]
        public void backward_range_read_doesnt_return_expired_records()
        {
            EventRecord[] records;
            Assert.AreEqual(RangeReadResult.Success, ReadIndex.ReadStreamEventsBackward("ES", -1, 100, out records));
            Assert.AreEqual(2, records.Length);
            Assert.AreEqual(_r6, records[0]);
            Assert.AreEqual(_r5, records[1]);
        }
    }
}
